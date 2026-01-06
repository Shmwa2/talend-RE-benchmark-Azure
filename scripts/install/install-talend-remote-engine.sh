#!/bin/bash
#
# Talend Remote Engine Installation Script
# This script installs and configures Talend Remote Engine on the VM
#

set -euo pipefail

# Configuration
TALEND_VERSION="${TALEND_VERSION:-2.13.0}"
TALEND_DOWNLOAD_URL="${TALEND_DOWNLOAD_URL:-}"
INSTALL_DIR="/opt/talend/remote-engine"
DATA_DIR="/data/talend"
LOG_FILE="/var/log/talend-install.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "${LOG_FILE}"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "${LOG_FILE}"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "${LOG_FILE}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Run as azureuser."
fi

log "Starting Talend Remote Engine installation..."

# Step 1: Verify Java installation
log "Checking Java installation..."
if ! command -v java &> /dev/null; then
    error "Java is not installed. Please install openjdk-11-jdk first."
fi

JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
if [[ "${JAVA_VERSION}" != "11" ]]; then
    error "Java 11 is required. Current version: ${JAVA_VERSION}"
fi

log "Java 11 detected: OK"

# Step 2: Check if download URL is provided
if [[ -z "${TALEND_DOWNLOAD_URL}" ]]; then
    warn "TALEND_DOWNLOAD_URL is not set."
    warn "You need to manually download Talend Remote Engine from Talend Cloud Management Console."
    warn "Place the zip file in /tmp/talend-remote-engine.zip and run this script again."

    if [[ ! -f /tmp/talend-remote-engine.zip ]]; then
        error "Talend Remote Engine zip file not found at /tmp/talend-remote-engine.zip"
    fi
    log "Using existing file: /tmp/talend-remote-engine.zip"
else
    # Step 3: Download Talend Remote Engine
    log "Downloading Talend Remote Engine v${TALEND_VERSION}..."
    curl -L -o /tmp/talend-remote-engine.zip "${TALEND_DOWNLOAD_URL}" || \
        error "Failed to download Talend Remote Engine"
fi

# Step 4: Create installation directory
log "Creating installation directory..."
sudo mkdir -p "${INSTALL_DIR}"
sudo chown -R "$(whoami):$(whoami)" "${INSTALL_DIR}"

# Step 5: Extract archive
log "Extracting Talend Remote Engine..."
unzip -q /tmp/talend-remote-engine.zip -d "${INSTALL_DIR}" || \
    error "Failed to extract Talend Remote Engine"

# Find the actual installation directory (may vary)
ACTUAL_DIR=$(find "${INSTALL_DIR}" -maxdepth 1 -type d -name "*emote*" | head -1)
if [[ -z "${ACTUAL_DIR}" ]]; then
    ACTUAL_DIR="${INSTALL_DIR}"
else
    # Move files to parent directory
    mv "${ACTUAL_DIR}"/* "${INSTALL_DIR}/"
    rmdir "${ACTUAL_DIR}"
fi

# Step 6: Set permissions
log "Setting permissions..."
chmod +x "${INSTALL_DIR}"/*.sh 2>/dev/null || true

# Step 7: Create data directories
log "Creating data directories..."
sudo mkdir -p "${DATA_DIR}"/{work,logs,temp}
sudo chown -R "$(whoami):$(whoami)" "${DATA_DIR}"

# Step 8: Configure environment variables
log "Configuring environment variables..."
cat >> ~/.bashrc <<EOF

# Talend Remote Engine
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export TALEND_HOME=${INSTALL_DIR}
export TALEND_WORKSPACE=${DATA_DIR}/work
export PATH=\$PATH:\${TALEND_HOME}
EOF

source ~/.bashrc

# Step 9: Create systemd service
log "Creating systemd service..."
sudo tee /etc/systemd/system/talend-remote-engine.service > /dev/null <<EOF
[Unit]
Description=Talend Remote Engine
Documentation=https://help.talend.com/
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User=$(whoami)
Group=$(whoami)
Environment="JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64"
Environment="TALEND_HOME=${INSTALL_DIR}"
Environment="TALEND_WORKSPACE=${DATA_DIR}/work"
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/start.sh
ExecStop=${INSTALL_DIR}/stop.sh
Restart=on-failure
RestartSec=10
TimeoutStartSec=300
StandardOutput=append:${DATA_DIR}/logs/engine.log
StandardError=append:${DATA_DIR}/logs/engine-error.log

[Install]
WantedBy=multi-user.target
EOF

# Step 10: Reload systemd and enable service
log "Enabling Talend Remote Engine service..."
sudo systemctl daemon-reload
sudo systemctl enable talend-remote-engine

# Step 11: Display next steps
log "Installation completed successfully!"
echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo "1. Configure pairing key in: ${INSTALL_DIR}/etc/engine.properties"
echo "   talend.remote.engine.pre.authorized.key=<YOUR_PAIRING_KEY>"
echo ""
echo "2. Start the service:"
echo "   sudo systemctl start talend-remote-engine"
echo ""
echo "3. Check status:"
echo "   sudo systemctl status talend-remote-engine"
echo "   sudo journalctl -u talend-remote-engine -f"
echo ""
echo "4. Verify in Talend Cloud Management Console"
echo "=========================================="
echo ""

log "Installation log saved to: ${LOG_FILE}"
