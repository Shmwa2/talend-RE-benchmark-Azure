#!/bin/bash
#
# Benchmark Execution Script for Talend Remote Engine
# Runs a benchmark scenario and collects metrics
#

set -euo pipefail

# Configuration
SCENARIO_FILE="${1:-}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RESULTS_BASE_DIR="${PROJECT_ROOT}/benchmark/results"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="${RESULTS_BASE_DIR}/${TIMESTAMP}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."

    if ! command -v jq &> /dev/null; then
        error "jq is not installed. Please install it: sudo apt install jq"
    fi

    if ! command -v sar &> /dev/null; then
        warn "sysstat is not installed. Some metrics may not be collected."
    fi

    log "Dependencies OK"
}

# Validate scenario file
validate_scenario() {
    if [[ -z "${SCENARIO_FILE}" ]]; then
        error "Usage: $0 <scenario-file.json>"
    fi

    if [[ ! -f "${SCENARIO_FILE}" ]]; then
        error "Scenario file not found: ${SCENARIO_FILE}"
    fi

    # Validate JSON
    if ! jq empty "${SCENARIO_FILE}" 2>/dev/null; then
        error "Invalid JSON in scenario file"
    fi

    log "Scenario file validated: ${SCENARIO_FILE}"
}

# Parse scenario configuration
parse_scenario() {
    SCENARIO_NAME=$(jq -r '.name // "unnamed-scenario"' "${SCENARIO_FILE}")
    SCENARIO_DESC=$(jq -r '.description // ""' "${SCENARIO_FILE}")
    TALEND_JOB=$(jq -r '.talend_job // ""' "${SCENARIO_FILE}")
    DATASET_SOURCE=$(jq -r '.dataset.source // ""' "${SCENARIO_FILE}")
    EXPECTED_MAX_TIME=$(jq -r '.expected.max_execution_time_sec // 0' "${SCENARIO_FILE}")

    info "Scenario: ${SCENARIO_NAME}"
    info "Description: ${SCENARIO_DESC}"
    info "Talend Job: ${TALEND_JOB}"
}

# Display banner
display_banner() {
    echo ""
    echo "=========================================="
    echo "  Talend Remote Engine Benchmark"
    echo "=========================================="
    echo "Scenario    : ${SCENARIO_NAME}"
    echo "Timestamp   : ${TIMESTAMP}"
    echo "Results Dir : ${RESULTS_DIR}"
    echo "=========================================="
    echo ""
}

# Pre-flight checks
preflight_checks() {
    log "Running pre-flight checks..."

    # Check if Talend Remote Engine is running
    if ! systemctl is-active --quiet talend-remote-engine; then
        error "Talend Remote Engine service is not running. Start it with: sudo systemctl start talend-remote-engine"
    fi

    # Check disk space
    DATA_DISK_AVAIL=$(df -BG /data | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ ${DATA_DISK_AVAIL} -lt 10 ]]; then
        warn "Low disk space on /data: ${DATA_DISK_AVAIL}GB available"
    fi

    log "Pre-flight checks passed"
}

# Execute Talend job
execute_talend_job() {
    log "Executing Talend job: ${TALEND_JOB}"

    # NOTE: This is a placeholder for actual Talend job execution
    # In production, you would:
    # 1. Use Talend Cloud Management Console API to trigger the job
    # 2. Or use Talend CommandLine tool if available
    # 3. Poll for job completion

    # Example using Talend Cloud API (requires authentication setup):
    # curl -X POST "https://api.us.cloud.talend.com/tmc/v2.6/executions/tasks" \
    #      -H "Authorization: Bearer ${TALEND_API_TOKEN}" \
    #      -H "Content-Type: application/json" \
    #      -d "{\"executable\":\"${TALEND_JOB}\",\"engine\":\"azure-benchmark-engine-dev\"}"

    # For demonstration, we'll simulate a job execution
    warn "Simulating Talend job execution (replace this with actual API call)"

    # Simulate job execution time
    SIMULATED_DURATION=${EXPECTED_MAX_TIME:-60}
    if [[ ${SIMULATED_DURATION} -eq 0 ]]; then
        SIMULATED_DURATION=60
    fi

    info "Simulating job execution for ${SIMULATED_DURATION} seconds..."
    sleep "${SIMULATED_DURATION}"

    EXECUTION_RESULT=0  # Success
    log "Job execution completed with exit code: ${EXECUTION_RESULT}"
}

# Generate result JSON
generate_result() {
    local exec_time=$1
    local exit_code=$2

    log "Generating result summary..."

    # Calculate throughput if dataset info is available
    DATASET_RECORDS=$(jq -r '.dataset.records // 0' "${SCENARIO_FILE}")
    if [[ ${DATASET_RECORDS} -gt 0 ]] && [[ ${exec_time} -gt 0 ]]; then
        THROUGHPUT=$((DATASET_RECORDS / exec_time))
    else
        THROUGHPUT=0
    fi

    # Get VM size from environment or use default
    VM_SIZE="${VM_SIZE:-Standard_D8s_v5}"

    # Read summary stats if available
    AVG_CPU="N/A"
    PEAK_MEM="N/A"
    if [[ -f "${RESULTS_DIR}/summary-stats.txt" ]]; then
        AVG_CPU=$(grep "Average CPU Usage" "${RESULTS_DIR}/summary-stats.txt" | awk '{print $4}' || echo "N/A")
        PEAK_MEM=$(grep "Peak Used" "${RESULTS_DIR}/summary-stats.txt" | awk '{print $3,$4}' || echo "N/A")
    fi

    # Create result JSON
    jq -n \
        --arg benchmark_id "${TIMESTAMP}" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg scenario "${SCENARIO_NAME}" \
        --arg vm_size "${VM_SIZE}" \
        --argjson exec_time "${exec_time}" \
        --argjson exit_code "${exit_code}" \
        --argjson throughput "${THROUGHPUT}" \
        --arg avg_cpu "${AVG_CPU}" \
        --arg peak_mem "${PEAK_MEM}" \
        '{
            benchmark_id: $benchmark_id,
            timestamp: $timestamp,
            scenario: $scenario,
            vm_size: $vm_size,
            metrics: {
                execution_time_sec: $exec_time,
                throughput_records_per_sec: $throughput,
                avg_cpu_percent: $avg_cpu,
                peak_memory: $peak_mem,
                exit_code: $exit_code
            }
        }' > "${RESULTS_DIR}/summary.json"

    # Copy scenario file to results
    cp "${SCENARIO_FILE}" "${RESULTS_DIR}/scenario.json"

    log "Result summary saved to: ${RESULTS_DIR}/summary.json"
}

# Main execution flow
main() {
    check_dependencies
    validate_scenario
    parse_scenario
    display_banner
    preflight_checks

    # Create results directory
    mkdir -p "${RESULTS_DIR}"

    # Start metrics collection
    log "Starting metrics collection..."
    "${PROJECT_ROOT}/scripts/benchmark/collect-metrics.sh" start "${RESULTS_DIR}"

    # Execute benchmark
    START_TIME=$(date +%s)
    execute_talend_job
    END_TIME=$(date +%s)
    EXECUTION_TIME=$((END_TIME - START_TIME))

    # Stop metrics collection
    log "Stopping metrics collection..."
    VM_RESOURCE_ID="${VM_RESOURCE_ID:-}" "${PROJECT_ROOT}/scripts/benchmark/collect-metrics.sh" stop "${RESULTS_DIR}"

    # Generate results
    generate_result "${EXECUTION_TIME}" "${EXECUTION_RESULT}"

    # Generate report
    log "Generating benchmark report..."
    "${PROJECT_ROOT}/scripts/benchmark/generate-report.sh" "${RESULTS_DIR}"

    # Display summary
    echo ""
    echo "=========================================="
    echo "  Benchmark Completed"
    echo "=========================================="
    echo "Execution Time: ${EXECUTION_TIME}s"
    echo "Exit Code     : ${EXECUTION_RESULT}"
    echo "Results       : ${RESULTS_DIR}"
    echo "Report        : ${RESULTS_DIR}/report.md"
    echo "=========================================="
    echo ""

    if [[ ${EXECUTION_RESULT} -eq 0 ]]; then
        log "Benchmark completed successfully!"
    else
        warn "Benchmark completed with errors. Check logs for details."
    fi
}

# Run main function
main "$@"
