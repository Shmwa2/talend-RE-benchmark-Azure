#!/bin/bash
#
# Talend Remote Engine Health Check Script
# Checks the health status of the Talend Remote Engine
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check() {
    if [[ $1 -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} $2"
        return 0
    else
        echo -e "${RED}✗${NC} $2"
        return 1
    fi
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "========================================"
echo "Talend Remote Engine Health Check"
echo "========================================"
echo ""

# Check service status
echo "[Service Status]"
systemctl is-active --quiet talend-remote-engine
check $? "Talend Remote Engine service is running"

# Check Java
echo ""
echo "[Java Environment]"
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    check 0 "Java installed: ${JAVA_VERSION}"
else
    check 1 "Java not found"
fi

# Check disk space
echo ""
echo "[Disk Space]"
DATA_DISK_USAGE=$(df -h /data | awk 'NR==2 {print $5}' | sed 's/%//')
if [[ ${DATA_DISK_USAGE} -lt 80 ]]; then
    check 0 "Data disk usage: ${DATA_DISK_USAGE}%"
else
    warn "Data disk usage high: ${DATA_DISK_USAGE}%"
fi

# Check memory
echo ""
echo "[Memory]"
MEM_AVAILABLE=$(free -m | awk 'NR==2 {print $7}')
MEM_TOTAL=$(free -m | awk 'NR==2 {print $2}')
MEM_USAGE_PCT=$((100 - (MEM_AVAILABLE * 100 / MEM_TOTAL)))
if [[ ${MEM_USAGE_PCT} -lt 90 ]]; then
    check 0 "Memory usage: ${MEM_USAGE_PCT}% (${MEM_AVAILABLE}MB available)"
else
    warn "Memory usage high: ${MEM_USAGE_PCT}%"
fi

# Check CPU
echo ""
echo "[CPU]"
CPU_IDLE=$(mpstat 1 1 | awk '/Average:/ {print $NF}')
echo -e "${GREEN}✓${NC} CPU idle: ${CPU_IDLE}%"

# Check logs for errors
echo ""
echo "[Recent Errors in Logs]"
ERROR_COUNT=$(sudo journalctl -u talend-remote-engine --since "1 hour ago" | grep -ci "error" || echo "0")
if [[ ${ERROR_COUNT} -eq 0 ]]; then
    check 0 "No errors in last hour"
else
    warn "Found ${ERROR_COUNT} error(s) in last hour"
fi

# Check network connectivity
echo ""
echo "[Network Connectivity]"
if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
    check 0 "Internet connectivity OK"
else
    check 1 "Internet connectivity failed"
fi

echo ""
echo "========================================"
echo "Health check completed"
echo "========================================"
