#!/bin/bash
#
# 汎用ベンチマークツール
# Azure VM上で任意のコマンド/ジョブを実行し、リソース使用量を測定
#
# 使い方:
#   ./benchmark.sh start [name]           # メトリクス収集開始
#   ./benchmark.sh stop                   # メトリクス収集停止、レポート生成
#   ./benchmark.sh run "command" [name]   # コマンド実行しながらメトリクス収集
#   ./benchmark.sh status                 # 現在の状態確認
#   ./benchmark.sh list                   # 過去の結果一覧
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"
STATE_FILE="${SCRIPT_DIR}/.benchmark_state"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# 依存関係チェック
check_deps() {
    local missing=()
    for cmd in jq sar iostat vmstat; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Missing tools: ${missing[*]}"
        warn "Install with: sudo apt install jq sysstat"
    fi
}

# メトリクス収集開始
start_metrics() {
    local output_dir="$1"
    mkdir -p "$output_dir"

    log "Starting metrics collection..."

    # CPU (sar)
    sar -u 1 > "$output_dir/cpu.log" 2>&1 &
    echo $! > "$output_dir/sar_cpu.pid"

    # Memory (vmstat)
    vmstat 1 > "$output_dir/memory.log" 2>&1 &
    echo $! > "$output_dir/vmstat.pid"

    # Disk I/O (iostat)
    iostat -x 1 > "$output_dir/disk_io.log" 2>&1 &
    echo $! > "$output_dir/iostat.pid"

    # Network (sar)
    sar -n DEV 1 > "$output_dir/network.log" 2>&1 &
    echo $! > "$output_dir/sar_net.pid"

    log "Metrics collection started"
}

# メトリクス収集停止
stop_metrics() {
    local output_dir="$1"

    log "Stopping metrics collection..."

    for pidfile in "$output_dir"/*.pid; do
        [[ -f "$pidfile" ]] || continue
        pid=$(cat "$pidfile")
        kill "$pid" 2>/dev/null || true
        rm -f "$pidfile"
    done

    log "Metrics collection stopped"
}

# Azure Monitor メトリクス取得
collect_azure_metrics() {
    local output_dir="$1"
    local start_time="$2"
    local end_time="$3"

    if [[ -z "${VM_RESOURCE_ID:-}" ]]; then
        warn "VM_RESOURCE_ID not set. Skipping Azure Monitor metrics."
        return
    fi

    if ! command -v az &>/dev/null; then
        warn "Azure CLI not installed. Skipping Azure Monitor metrics."
        return
    fi

    log "Collecting Azure Monitor metrics..."

    az monitor metrics list \
        --resource "$VM_RESOURCE_ID" \
        --metric "Percentage CPU" "Available Memory Bytes" \
                 "Disk Read Bytes" "Disk Write Bytes" \
                 "Network In Total" "Network Out Total" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --interval PT1M \
        --output json > "$output_dir/azure_metrics.json" 2>/dev/null || \
        warn "Failed to collect Azure metrics"
}

# サマリー統計生成
generate_summary() {
    local output_dir="$1"
    local duration="$2"
    local command="${3:-manual}"
    local exit_code="${4:-0}"

    log "Generating summary..."

    # CPU平均 (sar -u: $3=%user, $5=%system, $NF=%idle when $2=="all")
    local avg_cpu="N/A"
    local avg_cpu_user="N/A"
    local avg_cpu_system="N/A"
    local avg_cpu_idle="N/A"
    if [[ -f "$output_dir/cpu.log" ]]; then
        # 各行から平均を計算（Average行がない場合も対応）
        avg_cpu_user=$(awk '$2=="all" && $3~/^[0-9]/ {sum+=$3; count++} END {if(count>0) printf "%.2f", sum/count}' "$output_dir/cpu.log")
        avg_cpu_system=$(awk '$2=="all" && $5~/^[0-9]/ {sum+=$5; count++} END {if(count>0) printf "%.2f", sum/count}' "$output_dir/cpu.log")
        avg_cpu_idle=$(awk '$2=="all" && $NF~/^[0-9]/ {sum+=$NF; count++} END {if(count>0) printf "%.2f", sum/count}' "$output_dir/cpu.log")
        # 合計CPU使用率 = user + system
        if [[ -n "$avg_cpu_user" && -n "$avg_cpu_system" ]]; then
            avg_cpu=$(awk "BEGIN {printf \"%.2f\", $avg_cpu_user + $avg_cpu_system}" 2>/dev/null || echo "N/A")
        fi
        [[ -z "$avg_cpu" ]] && avg_cpu="N/A"
        [[ -z "$avg_cpu_user" ]] && avg_cpu_user="N/A"
        [[ -z "$avg_cpu_system" ]] && avg_cpu_system="N/A"
        [[ -z "$avg_cpu_idle" ]] && avg_cpu_idle="N/A"
    fi

    # メモリ統計 (vmstat: $4=free, $5=buff, $6=cache)
    # 使用量 = total - free - buff - cache は計算が複雑なので、freeを記録
    local mem_free_min="N/A"
    local avg_mem_free="N/A"
    if [[ -f "$output_dir/memory.log" ]]; then
        # vmstat の $4 が free memory (KB)
        mem_free_min=$(awk 'NR>2 && $4~/^[0-9]+$/ {print $4}' "$output_dir/memory.log" | sort -n | head -1)
        avg_mem_free=$(awk 'NR>2 && $4~/^[0-9]+$/ {sum+=$4; count++} END {if(count>0) print int(sum/count)}' "$output_dir/memory.log")
        [[ -z "$mem_free_min" ]] && mem_free_min="N/A"
        [[ -z "$avg_mem_free" ]] && avg_mem_free="N/A"
    fi

    # JSON出力
    jq -n \
        --arg id "$(basename "$output_dir")" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg command "$command" \
        --argjson duration "$duration" \
        --argjson exit_code "$exit_code" \
        --arg avg_cpu "$avg_cpu" \
        --arg avg_cpu_user "$avg_cpu_user" \
        --arg avg_cpu_system "$avg_cpu_system" \
        --arg avg_cpu_idle "$avg_cpu_idle" \
        --arg mem_free_min_kb "$mem_free_min" \
        --arg avg_mem_free_kb "$avg_mem_free" \
        --arg vm_size "${VM_SIZE:-unknown}" \
        '{
            benchmark_id: $id,
            timestamp: $timestamp,
            command: $command,
            duration_seconds: $duration,
            exit_code: $exit_code,
            vm_size: $vm_size,
            metrics: {
                cpu_avg_percent: $avg_cpu,
                cpu_user_percent: $avg_cpu_user,
                cpu_system_percent: $avg_cpu_system,
                cpu_idle_percent: $avg_cpu_idle,
                memory_free_min_kb: $mem_free_min_kb,
                memory_free_avg_kb: $avg_mem_free_kb
            }
        }' > "$output_dir/summary.json"

    log "Summary saved to $output_dir/summary.json"
}

# レポート生成
generate_report() {
    local output_dir="$1"

    [[ -f "$output_dir/summary.json" ]] || error "summary.json not found"

    local id=$(jq -r '.benchmark_id' "$output_dir/summary.json")
    local timestamp=$(jq -r '.timestamp' "$output_dir/summary.json")
    local command=$(jq -r '.command' "$output_dir/summary.json")
    local duration=$(jq -r '.duration_seconds' "$output_dir/summary.json")
    local exit_code=$(jq -r '.exit_code' "$output_dir/summary.json")
    local vm_size=$(jq -r '.vm_size' "$output_dir/summary.json")
    local avg_cpu=$(jq -r '.metrics.cpu_avg_percent' "$output_dir/summary.json")
    local cpu_user=$(jq -r '.metrics.cpu_user_percent' "$output_dir/summary.json")
    local cpu_system=$(jq -r '.metrics.cpu_system_percent' "$output_dir/summary.json")
    local cpu_idle=$(jq -r '.metrics.cpu_idle_percent' "$output_dir/summary.json")
    local mem_free_min=$(jq -r '.metrics.memory_free_min_kb' "$output_dir/summary.json")
    local mem_free_avg=$(jq -r '.metrics.memory_free_avg_kb' "$output_dir/summary.json")

    cat > "$output_dir/report.md" <<EOF
# Benchmark Report

## Overview
| Item | Value |
|------|-------|
| **ID** | $id |
| **Timestamp** | $timestamp |
| **Duration** | ${duration}s |
| **Exit Code** | $exit_code |
| **VM Size** | $vm_size |

## Command
\`\`\`
$command
\`\`\`

## Resource Usage

### CPU
| Metric | Value |
|--------|-------|
| **Average Usage** | ${avg_cpu}% |
| User | ${cpu_user}% |
| System | ${cpu_system}% |
| Idle | ${cpu_idle}% |

### Memory
| Metric | Value |
|--------|-------|
| **Minimum Free** | ${mem_free_min} KB |
| Average Free | ${mem_free_avg} KB |

### Detailed Logs
- \`cpu.log\` - CPU usage (sar)
- \`memory.log\` - Memory usage (vmstat)
- \`disk_io.log\` - Disk I/O (iostat)
- \`network.log\` - Network (sar)
$(if [[ -f "$output_dir/azure_metrics.json" ]]; then echo "- \`azure_metrics.json\` - Azure Monitor metrics"; fi)

---
*Generated: $(date)*
EOF

    log "Report saved to $output_dir/report.md"
}

# コマンド: start
cmd_start() {
    local name="${1:-benchmark-$(date +%Y%m%d-%H%M%S)}"
    local output_dir="$RESULTS_DIR/$name"

    if [[ -f "$STATE_FILE" ]]; then
        error "Benchmark already running. Run 'stop' first."
    fi

    check_deps
    mkdir -p "$output_dir"

    # 状態保存
    jq -n \
        --arg name "$name" \
        --arg dir "$output_dir" \
        --arg start "$(date +%s)" \
        --arg start_iso "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{name: $name, dir: $dir, start_epoch: $start, start_time: $start_iso}' \
        > "$STATE_FILE"

    start_metrics "$output_dir"

    echo ""
    info "Benchmark '$name' started"
    info "Output: $output_dir"
    info "Run your job/command now, then execute: ./benchmark.sh stop"
    echo ""
}

# コマンド: stop
cmd_stop() {
    [[ -f "$STATE_FILE" ]] || error "No benchmark running. Run 'start' first."

    local output_dir=$(jq -r '.dir' "$STATE_FILE")
    local start_epoch=$(jq -r '.start_epoch' "$STATE_FILE")
    local start_iso=$(jq -r '.start_time' "$STATE_FILE")
    local end_epoch=$(date +%s)
    local end_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local duration=$((end_epoch - start_epoch))

    stop_metrics "$output_dir"
    collect_azure_metrics "$output_dir" "$start_iso" "$end_iso"
    generate_summary "$output_dir" "$duration" "manual" 0
    generate_report "$output_dir"

    rm -f "$STATE_FILE"

    echo ""
    info "Benchmark completed"
    info "Duration: ${duration}s"
    info "Results: $output_dir"
    info "Report: $output_dir/report.md"
    echo ""

    # サマリー表示
    cat "$output_dir/summary.json" | jq .
}

# コマンド: run
cmd_run() {
    local command="${1:-}"
    local name="${2:-benchmark-$(date +%Y%m%d-%H%M%S)}"

    [[ -n "$command" ]] || error "Usage: ./benchmark.sh run \"command\" [name]"

    if [[ -f "$STATE_FILE" ]]; then
        error "Benchmark already running. Run 'stop' first."
    fi

    check_deps

    local output_dir="$RESULTS_DIR/$name"
    mkdir -p "$output_dir"

    local start_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local start_epoch=$(date +%s)

    start_metrics "$output_dir"

    log "Executing: $command"
    echo ""

    # コマンド実行
    local exit_code=0
    eval "$command" || exit_code=$?

    echo ""
    local end_epoch=$(date +%s)
    local end_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local duration=$((end_epoch - start_epoch))

    stop_metrics "$output_dir"
    collect_azure_metrics "$output_dir" "$start_iso" "$end_iso"
    generate_summary "$output_dir" "$duration" "$command" "$exit_code"
    generate_report "$output_dir"

    echo ""
    info "Benchmark completed"
    info "Duration: ${duration}s"
    info "Exit code: $exit_code"
    info "Results: $output_dir"
    info "Report: $output_dir/report.md"
    echo ""

    cat "$output_dir/summary.json" | jq .
}

# コマンド: status
cmd_status() {
    if [[ -f "$STATE_FILE" ]]; then
        local name=$(jq -r '.name' "$STATE_FILE")
        local start=$(jq -r '.start_epoch' "$STATE_FILE")
        local now=$(date +%s)
        local elapsed=$((now - start))

        info "Benchmark running: $name"
        info "Elapsed: ${elapsed}s"
    else
        info "No benchmark running"
    fi
}

# コマンド: list
cmd_list() {
    if [[ ! -d "$RESULTS_DIR" ]]; then
        info "No results yet"
        return
    fi

    echo ""
    echo "Past Benchmarks:"
    echo "----------------"

    for dir in "$RESULTS_DIR"/*/; do
        [[ -d "$dir" ]] || continue
        local name=$(basename "$dir")
        if [[ -f "$dir/summary.json" ]]; then
            local duration=$(jq -r '.duration_seconds' "$dir/summary.json")
            local cpu=$(jq -r '.metrics.cpu_avg_percent' "$dir/summary.json")
            echo "$name  |  ${duration}s  |  CPU: ${cpu}%"
        else
            echo "$name  |  (incomplete)"
        fi
    done
    echo ""
}

# ヘルプ
show_help() {
    cat <<EOF
Usage: ./benchmark.sh <command> [options]

Commands:
  start [name]              Start metrics collection
  stop                      Stop metrics collection and generate report
  run "command" [name]      Execute command while collecting metrics
  status                    Show current benchmark status
  list                      List past benchmark results

Environment Variables:
  VM_RESOURCE_ID            Azure VM Resource ID for Azure Monitor metrics
  VM_SIZE                   VM size label for report (default: unknown)

Examples:
  # Manual mode
  ./benchmark.sh start my-benchmark
  # ... run your Talend job ...
  ./benchmark.sh stop

  # Auto mode
  ./benchmark.sh run "sleep 30" test-run

  # With Azure metrics
  VM_RESOURCE_ID="/subscriptions/.../vm" ./benchmark.sh start
EOF
}

# メイン
case "${1:-help}" in
    start)  cmd_start "${2:-}" ;;
    stop)   cmd_stop ;;
    run)    cmd_run "${2:-}" "${3:-}" ;;
    status) cmd_status ;;
    list)   cmd_list ;;
    help|--help|-h) show_help ;;
    *)      error "Unknown command: $1. Run './benchmark.sh help' for usage." ;;
esac
