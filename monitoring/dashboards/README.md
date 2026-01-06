# Azure Dashboard for Talend Benchmark Monitoring

## Overview

This directory contains configuration for Azure Dashboard to visualize Talend Remote Engine performance metrics.

## Creating the Dashboard

### Method 1: Manual Creation (Recommended)

1. **Navigate to Azure Portal**
   ```
   https://portal.azure.com/#dashboard
   ```

2. **Create New Dashboard**
   - Click "New dashboard"
   - Name: "Talend Benchmark Performance"

3. **Add Tiles**

   #### Tile 1: CPU Usage
   - Type: Metrics Chart
   - Resource: Select your Talend VM
   - Metric Namespace: Virtual Machine Host
   - Metric: Percentage CPU
   - Aggregation: Average
   - Time Range: Last 6 hours
   - Chart Type: Line chart

   #### Tile 2: Memory Usage
   - Type: Metrics Chart
   - Resource: Select your Talend VM
   - Metric: Available Memory Bytes
   - Aggregation: Average
   - Time Range: Last 6 hours

   #### Tile 3: Disk IOPS
   - Type: Metrics Chart
   - Metrics:
     - Disk Read Operations/Sec
     - Disk Write Operations/Sec
   - Time Range: Last 6 hours

   #### Tile 4: Network Throughput
   - Type: Metrics Chart
   - Metrics:
     - Network In Total
     - Network Out Total
   - Time Range: Last 6 hours

   #### Tile 5: Benchmark Results Table
   - Type: Logs (Query)
   - Log Analytics Workspace: Select your workspace
   - Query: Use queries from `../queries/azure-monitor-queries.kql`

4. **Save Dashboard**
   - Click "Done customizing"
   - Save to resource group

### Method 2: Using Azure CLI

```bash
# Export existing dashboard
az portal dashboard show \
    --name "Talend Benchmark Performance" \
    --resource-group "rg-talend-benchmark-dev" \
    --output json > talend-performance-dashboard.json

# Import dashboard
az portal dashboard create \
    --resource-group "rg-talend-benchmark-dev" \
    --name "Talend Benchmark Performance" \
    --input-path talend-performance-dashboard.json
```

## Dashboard Panels

### 1. Overview Section
- VM Status (Online/Offline)
- Talend Remote Engine Status
- Current Resource Utilization Summary

### 2. Real-Time Metrics
- **CPU Usage**: Line chart showing % CPU over time
- **Memory**: Available memory in GB
- **Disk I/O**: Read/Write operations per second
- **Network**: Incoming/Outgoing bandwidth

### 3. Benchmark History
- **Execution Timeline**: Bar chart of benchmark runs
- **Performance Trends**: Throughput over time
- **Resource Correlation**: How resources were utilized during benchmarks

### 4. Alerts & Health
- Active Alerts count
- Failed Jobs count
- Disk Space Warning

## Key Metrics to Monitor

| Metric | Threshold | Action |
|--------|-----------|--------|
| CPU Usage | > 90% for 5 min | Consider VM upsize |
| Memory Available | < 2GB | Increase VM memory |
| Disk Free Space | < 10% | Clean up or expand disk |
| Network Errors | > 0 | Check network config |

## Useful Dashboard Queries

### Current System Health
```kql
Perf
| where TimeGenerated > ago(5m)
| where ObjectName in ("Processor", "Memory", "LogicalDisk")
| summarize
    AvgCPU = avgif(CounterValue, CounterName == "% Processor Time"),
    AvgMemoryMB = avgif(CounterValue, CounterName == "Available MBytes"),
    DiskFree = avgif(CounterValue, CounterName == "% Free Space")
| extend Status = case(
    AvgCPU > 90, "⚠️ High CPU",
    AvgMemoryMB < 2048, "⚠️ Low Memory",
    DiskFree < 10, "⚠️ Low Disk",
    "✅ Healthy"
)
| project Status, AvgCPU, AvgMemoryMB, DiskFree
```

### Last 10 Benchmark Runs
```kql
// This assumes benchmark results are uploaded to custom logs
CustomLogs_BenchmarkResults_CL
| where TimeGenerated > ago(30d)
| order by TimeGenerated desc
| take 10
| project
    Time = TimeGenerated,
    Scenario = Scenario_s,
    Duration = ExecutionTime_s,
    Throughput = Throughput_d,
    Status = iff(ExitCode_d == 0, "✅", "❌")
```

## Exporting Dashboard

To share dashboard configuration:

```bash
# Export to JSON
az portal dashboard show \
    --name "Talend Benchmark Performance" \
    --resource-group "rg-talend-benchmark-dev" \
    > talend-performance-dashboard.json

# The exported JSON can be version controlled and shared
```

## Customization Tips

1. **Time Ranges**: Adjust based on benchmark duration
   - Quick tests: Last 1 hour
   - Long-running benchmarks: Last 24 hours

2. **Refresh Interval**: Set to 5 minutes for near real-time monitoring

3. **Alerts Integration**: Add alert tiles to show active alerts inline

4. **Cost Monitoring**: Add Azure Cost Management tile to track expenses

## Alternative: Grafana Dashboard

If you prefer Grafana:

1. Install Azure Monitor Data Source
2. Import dashboard from `grafana-dashboard.json` (template)
3. Connect to your Log Analytics Workspace

See [Grafana Azure Monitor documentation](https://grafana.com/docs/grafana/latest/datasources/azuremonitor/)

## Next Steps

1. Create dashboard in Azure Portal
2. Pin frequently used KQL queries
3. Set up alert rules from dashboard
4. Share dashboard with team
5. Schedule automated reports (Azure Workbooks)

---

For advanced monitoring, consider Azure Workbooks for interactive reports.
