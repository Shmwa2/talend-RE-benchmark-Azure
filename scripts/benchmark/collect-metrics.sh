#!/bin/bash
#
# Metrics Collection Script for Talend Benchmark
# Collects system and Azure metrics during benchmark execution
#

set -euo pipefail

# Default values
MODE="${1:-start}"
OUTPUT_DIR="${2:-.}"
VM_RESOURCE_ID="${VM_RESOURCE_ID:-}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

case "${MODE}" in
    start)
        log "Starting metrics collection..."
        mkdir -p "${OUTPUT_DIR}"

        # CPU metrics with sar
        log "Starting CPU monitoring (sar)..."
        sar -u 1 > "${OUTPUT_DIR}/cpu.log" 2>&1 &
        echo $! > "${OUTPUT_DIR}/sar.pid"

        # Disk I/O metrics
        log "Starting disk I/O monitoring (iostat)..."
        iostat -x 1 > "${OUTPUT_DIR}/io.log" 2>&1 &
        echo $! > "${OUTPUT_DIR}/iostat.pid"

        # Memory metrics
        log "Starting memory monitoring (vmstat)..."
        vmstat 1 > "${OUTPUT_DIR}/mem.log" 2>&1 &
        echo $! > "${OUTPUT_DIR}/vmstat.pid"

        # Network metrics
        log "Starting network monitoring (sar -n DEV)..."
        sar -n DEV 1 > "${OUTPUT_DIR}/network.log" 2>&1 &
        echo $! > "${OUTPUT_DIR}/sar-net.pid"

        log "Metrics collection started. PIDs saved in ${OUTPUT_DIR}/"
        ;;

    stop)
        log "Stopping metrics collection..."

        # Stop all monitoring processes
        for pidfile in "${OUTPUT_DIR}"/*.pid; do
            if [[ -f "${pidfile}" ]]; then
                pid=$(cat "${pidfile}")
                kill "${pid}" 2>/dev/null || warn "Process ${pid} not found"
                rm -f "${pidfile}"
            fi
        done

        # Collect Azure Monitor metrics (if VM_RESOURCE_ID is set)
        if [[ -n "${VM_RESOURCE_ID}" ]]; then
            log "Collecting Azure Monitor metrics..."

            END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            START_TIME=$(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%SZ)

            az monitor metrics list \
                --resource "${VM_RESOURCE_ID}" \
                --metric "Percentage CPU" "Available Memory Bytes" \
                         "Disk Read Bytes" "Disk Write Bytes" \
                         "Network In Total" "Network Out Total" \
                --start-time "${START_TIME}" \
                --end-time "${END_TIME}" \
                --interval PT1M \
                --output json > "${OUTPUT_DIR}/azure-metrics.json" 2>/dev/null || \
                warn "Failed to collect Azure metrics (az CLI may not be configured)"
        else
            warn "VM_RESOURCE_ID not set. Skipping Azure metrics collection."
            warn "Set VM_RESOURCE_ID environment variable to enable Azure Monitor integration."
        fi

        # Generate summary statistics
        log "Generating summary statistics..."

        # CPU summary
        if [[ -f "${OUTPUT_DIR}/cpu.log" ]]; then
            AVG_CPU=$(awk '/^Average:/ {print $3}' "${OUTPUT_DIR}/cpu.log" | tail -1)
            echo "Average CPU Usage: ${AVG_CPU}%" > "${OUTPUT_DIR}/summary-stats.txt"
        fi

        # Memory summary
        if [[ -f "${OUTPUT_DIR}/mem.log" ]]; then
            echo "Memory Statistics:" >> "${OUTPUT_DIR}/summary-stats.txt"
            echo "  Peak Used: $(awk 'NR>2 {print $3}' "${OUTPUT_DIR}/mem.log" | sort -rn | head -1) KB" >> "${OUTPUT_DIR}/summary-stats.txt"
            echo "  Avg Free: $(awk 'NR>2 {sum+=$4; count++} END {if(count>0) print int(sum/count)}' "${OUTPUT_DIR}/mem.log") KB" >> "${OUTPUT_DIR}/summary-stats.txt"
        fi

        # Disk I/O summary
        if [[ -f "${OUTPUT_DIR}/io.log" ]]; then
            echo "Disk I/O Summary:" >> "${OUTPUT_DIR}/summary-stats.txt"
            grep "sdc" "${OUTPUT_DIR}/io.log" | awk '{sum+=$4; count++} END {if(count>0) print "  Avg Read/s: " int(sum/count)}' >> "${OUTPUT_DIR}/summary-stats.txt"
            grep "sdc" "${OUTPUT_DIR}/io.log" | awk '{sum+=$5; count++} END {if(count>0) print "  Avg Write/s: " int(sum/count)}' >> "${OUTPUT_DIR}/summary-stats.txt"
        fi

        log "Metrics collection stopped."
        log "Results saved to: ${OUTPUT_DIR}/"
        cat "${OUTPUT_DIR}/summary-stats.txt" 2>/dev/null || true
        ;;

    baseline)
        log "Collecting baseline metrics (${3:-60} seconds)..."
        DURATION="${3:-60}"
        BASELINE_DIR="${OUTPUT_DIR}/baseline"
        mkdir -p "${BASELINE_DIR}"

        # Collect baseline for specified duration
        sar -u 1 "${DURATION}" > "${BASELINE_DIR}/cpu-baseline.log" &
        iostat -x 1 "${DURATION}" > "${BASELINE_DIR}/io-baseline.log" &
        vmstat 1 "${DURATION}" > "${BASELINE_DIR}/mem-baseline.log" &

        wait

        log "Baseline metrics collected in ${BASELINE_DIR}/"
        ;;

    *)
        echo "Usage: $0 {start|stop|baseline} <output_dir> [duration]"
        echo ""
        echo "Modes:"
        echo "  start     - Start metrics collection"
        echo "  stop      - Stop metrics collection and generate summary"
        echo "  baseline  - Collect baseline metrics for specified duration (default: 60s)"
        echo ""
        echo "Environment Variables:"
        echo "  VM_RESOURCE_ID  - Azure VM Resource ID for Azure Monitor integration"
        echo ""
        echo "Examples:"
        echo "  $0 start ./results/benchmark-001"
        echo "  VM_RESOURCE_ID=/subscriptions/.../vm123 $0 stop ./results/benchmark-001"
        echo "  $0 baseline ./results/baseline 300"
        exit 1
        ;;
esac
