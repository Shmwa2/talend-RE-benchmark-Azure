#!/bin/bash
#
# Benchmark Report Generation Script
# Generates a Markdown report from benchmark results
#

set -euo pipefail

RESULT_PATH="${1:-.}"

# Check if summary.json exists
if [[ ! -f "${RESULT_PATH}/summary.json" ]]; then
    echo "Error: summary.json not found in ${RESULT_PATH}"
    exit 1
fi

# Parse summary.json
BENCHMARK_ID=$(jq -r '.benchmark_id' "${RESULT_PATH}/summary.json")
TIMESTAMP=$(jq -r '.timestamp' "${RESULT_PATH}/summary.json")
SCENARIO=$(jq -r '.scenario' "${RESULT_PATH}/summary.json")
VM_SIZE=$(jq -r '.vm_size' "${RESULT_PATH}/summary.json")
EXEC_TIME=$(jq -r '.metrics.execution_time_sec' "${RESULT_PATH}/summary.json")
THROUGHPUT=$(jq -r '.metrics.throughput_records_per_sec' "${RESULT_PATH}/summary.json")
AVG_CPU=$(jq -r '.metrics.avg_cpu_percent' "${RESULT_PATH}/summary.json")
PEAK_MEM=$(jq -r '.metrics.peak_memory' "${RESULT_PATH}/summary.json")
EXIT_CODE=$(jq -r '.metrics.exit_code' "${RESULT_PATH}/summary.json")

# Determine status
if [[ ${EXIT_CODE} -eq 0 ]]; then
    STATUS="✅ Success"
else
    STATUS="❌ Failed (Exit Code: ${EXIT_CODE})"
fi

# Get scenario details if available
SCENARIO_DESC=""
DATASET_INFO=""
if [[ -f "${RESULT_PATH}/scenario.json" ]]; then
    SCENARIO_DESC=$(jq -r '.description // ""' "${RESULT_PATH}/scenario.json")
    DATASET_SIZE=$(jq -r '.dataset.size_gb // "N/A"' "${RESULT_PATH}/scenario.json")
    DATASET_RECORDS=$(jq -r '.dataset.records // "N/A"' "${RESULT_PATH}/scenario.json")
    DATASET_INFO="- **Size**: ${DATASET_SIZE} GB\n- **Records**: ${DATASET_RECORDS}"
fi

# Generate Markdown report
cat > "${RESULT_PATH}/report.md" <<EOF
# Talend Benchmark Report

## Overview

- **Benchmark ID**: \`${BENCHMARK_ID}\`
- **Timestamp**: ${TIMESTAMP}
- **Status**: ${STATUS}

---

## Scenario Information

- **Name**: ${SCENARIO}
- **Description**: ${SCENARIO_DESC}

### Dataset
${DATASET_INFO}

---

## Infrastructure

- **VM Size**: ${VM_SIZE}
- **OS**: Ubuntu 22.04 LTS
- **Java**: OpenJDK 11
- **Talend**: Remote Engine (Cloud)

---

## Performance Metrics

### Execution Summary

| Metric | Value |
|--------|-------|
| **Execution Time** | ${EXEC_TIME} seconds |
| **Throughput** | ${THROUGHPUT} records/sec |
| **Average CPU** | ${AVG_CPU} |
| **Peak Memory** | ${PEAK_MEM} |
| **Exit Code** | ${EXIT_CODE} |

### Detailed Metrics

#### CPU Usage
$(if [[ -f "${RESULT_PATH}/cpu.log" ]]; then
    echo "- Average User CPU: $(awk '/^Average:/ {print $3"%"}' "${RESULT_PATH}/cpu.log" | tail -1)"
    echo "- Average System CPU: $(awk '/^Average:/ {print $5"%"}' "${RESULT_PATH}/cpu.log" | tail -1)"
    echo "- CPU Idle: $(awk '/^Average:/ {print $NF"%"}' "${RESULT_PATH}/cpu.log" | tail -1)"
else
    echo "CPU metrics not available"
fi)

#### Memory Usage
$(if [[ -f "${RESULT_PATH}/mem.log" ]]; then
    echo "- Peak Memory Used: $(awk 'NR>2 {print $3}' "${RESULT_PATH}/mem.log" | sort -rn | head -1) KB"
    echo "- Average Free Memory: $(awk 'NR>2 {sum+=$4; count++} END {if(count>0) print int(sum/count)" KB"}' "${RESULT_PATH}/mem.log")"
else
    echo "Memory metrics not available"
fi)

#### Disk I/O
$(if [[ -f "${RESULT_PATH}/io.log" ]]; then
    echo "- Average Read Throughput: $(grep "sdc" "${RESULT_PATH}/io.log" | awk '{sum+=$6; count++} END {if(count>0) print int(sum/count)" KB/s"}' | tail -1)"
    echo "- Average Write Throughput: $(grep "sdc" "${RESULT_PATH}/io.log" | awk '{sum+=$7; count++} END {if(count>0) print int(sum/count)" KB/s"}' | tail -1)"
else
    echo "Disk I/O metrics not available"
fi)

---

## Files Generated

- \`summary.json\` - Machine-readable summary
- \`scenario.json\` - Scenario configuration
- \`cpu.log\` - CPU usage over time (sar)
- \`mem.log\` - Memory usage over time (vmstat)
- \`io.log\` - Disk I/O statistics (iostat)
- \`network.log\` - Network statistics (sar -n DEV)
- \`summary-stats.txt\` - Quick summary statistics
$(if [[ -f "${RESULT_PATH}/azure-metrics.json" ]]; then echo "- \`azure-metrics.json\` - Azure Monitor metrics"; fi)

---

## Analysis

### Performance Assessment

$(if [[ ${THROUGHPUT} -gt 0 ]]; then
    if [[ ${THROUGHPUT} -gt 50000 ]]; then
        echo "✅ **Excellent**: Throughput exceeds 50,000 records/sec"
    elif [[ ${THROUGHPUT} -gt 10000 ]]; then
        echo "✅ **Good**: Throughput is within acceptable range (10k-50k records/sec)"
    else
        echo "⚠️ **Suboptimal**: Throughput is below 10,000 records/sec"
    fi
else
    echo "ℹ️ Throughput calculation not available"
fi)

### Resource Utilization

$(if [[ "${AVG_CPU}" != "N/A" ]]; then
    CPU_NUM=$(echo "${AVG_CPU}" | sed 's/%//')
    if [[ -n "${CPU_NUM}" ]] && [[ ${CPU_NUM%.*} -lt 50 ]]; then
        echo "ℹ️ **CPU**: Low utilization (${AVG_CPU}) - consider smaller VM size for cost optimization"
    elif [[ -n "${CPU_NUM}" ]] && [[ ${CPU_NUM%.*} -gt 90 ]]; then
        echo "⚠️ **CPU**: High utilization (${AVG_CPU}) - may benefit from larger VM size"
    else
        echo "✅ **CPU**: Optimal utilization (${AVG_CPU})"
    fi
else
    echo "ℹ️ CPU utilization data not available"
fi)

---

## Recommendations

1. **Scaling**: $(if [[ "${AVG_CPU}" != "N/A" ]]; then
    CPU_NUM=$(echo "${AVG_CPU}" | sed 's/%//')
    if [[ -n "${CPU_NUM}" ]] && [[ ${CPU_NUM%.*} -gt 80 ]]; then
        echo "Consider upgrading to a larger VM size (e.g., Standard_D16s_v5) for better performance"
    else
        echo "Current VM size appears appropriate for this workload"
    fi
else
    echo "Review CPU metrics to determine optimal VM size"
fi)

2. **Cost Optimization**: $(if [[ "${AVG_CPU}" != "N/A" ]]; then
    CPU_NUM=$(echo "${AVG_CPU}" | sed 's/%//')
    if [[ -n "${CPU_NUM}" ]] && [[ ${CPU_NUM%.*} -lt 30 ]]; then
        echo "Low CPU utilization suggests downsizing VM could reduce costs"
    else
        echo "VM size is well-utilized for the workload"
    fi
else
    echo "Analyze resource utilization to identify cost-saving opportunities"
fi)

3. **Further Testing**: Run multiple iterations to establish baseline performance and identify variance

---

## Appendix

### Raw Data Files

All raw metrics are available in this directory:
\`${RESULT_PATH}\`

### How to Use This Data

1. **Compare Scenarios**: Run multiple scenarios and compare \`summary.json\` files
2. **Trend Analysis**: Collect multiple runs over time to identify performance trends
3. **Azure Monitor**: Upload \`azure-metrics.json\` to Log Analytics for advanced querying
4. **Visualization**: Use \`summary.json\` with tools like Grafana or Excel for charting

---

*Generated by Talend Benchmark Suite on $(date)*
EOF

echo "Report generated: ${RESULT_PATH}/report.md"
