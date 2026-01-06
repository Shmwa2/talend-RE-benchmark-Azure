#!/bin/bash
#
# System Configuration Script for Talend Remote Engine
# Optimizes system settings for ETL performance
#

set -euo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Configuring system for Talend Remote Engine..."

# Increase file descriptor limits
log "Setting file descriptor limits..."
sudo tee -a /etc/security/limits.conf > /dev/null <<EOF
# Talend Remote Engine limits
azureuser soft nofile 65536
azureuser hard nofile 65536
azureuser soft nproc 65536
azureuser hard nproc 65536
EOF

# Optimize sysctl parameters
log "Optimizing sysctl parameters..."
sudo tee -a /etc/sysctl.conf > /dev/null <<EOF
# Talend Remote Engine optimizations
vm.swappiness = 10
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.ip_local_port_range = 10000 65535
EOF

sudo sysctl -p

# Enable sysstat for monitoring
log "Enabling sysstat..."
sudo sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat 2>/dev/null || true
sudo systemctl enable sysstat
sudo systemctl start sysstat

log "System configuration completed."
