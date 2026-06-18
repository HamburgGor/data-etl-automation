#!/bin/bash
# ==============================================
# ETL Auto Service Uninstall Script
# Features:
#   - Stop & disable systemd service
#   - Remove service, start scripts, and cron files
#   - Optionally remove virtual environment and project directory
# ==============================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()    { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
error()  { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }
info()   { echo -e "${GREEN}[INFO] $1${NC}"; }
warn()   { echo -e "${YELLOW}[WARN] $1${NC}"; }

if [ "$(id -u)" -ne 0 ]; then
    error "Please run this script with root privilege (sudo ./scripts/uninstall.sh)"
fi

# Detect real user
if [ -n "${SUDO_USER:-}" ]; then
    RUN_USER="${SUDO_USER}"
else
    RUN_USER="$(whoami)"
fi

USER_HOME="/home/${RUN_USER}"
PROJECT_DIR="${USER_HOME}/data-etl-automation"
VENV_DIR="${USER_HOME}/Myvenv"
SERVICE_PREFIX="etl_auto"

info "===== Starting ETL service uninstallation ====="

# 1. Stop and disable all ETL services
log "Stopping and disabling services..."
for svc in $(systemctl list-unit-files --no-legend | grep "^${SERVICE_PREFIX}_" | awk '{print $1}'); do
    systemctl stop "${svc}" 2>/dev/null || true
    systemctl disable "${svc}" 2>/dev/null || true
    rm -f "/etc/systemd/system/${svc}"
    info "Removed service: ${svc}"
done

# 2. Remove start scripts
log "Removing start scripts..."
rm -f "${USER_HOME}/start_"*.sh
info "Start scripts removed"

# 3. Remove cron files
log "Removing cron configuration..."
rm -f /etc/cron.d/etl_check_* /etc/cron.d/etl_data_lifecycle 2>/dev/null || true
# Clean root's crontab from reboot entries (safe)
crontab -l 2>/dev/null | grep -v "Periodic reboot" | crontab - 2>/dev/null || true
info "Cron tasks removed"

# 4. Reload systemd
systemctl daemon-reload

# 5. Optional cleanup (uncomment if you want to fully remove)
# warn "Do you want to remove the virtual environment (${VENV_DIR})? [y/N]"
# read -r answer
# if [[ "$answer" =~ ^[Yy]$ ]]; then
#     rm -rf "${VENV_DIR}"
#     info "Virtual environment removed"
# fi
# 
# warn "Do you want to remove the project directory (${PROJECT_DIR})? [y/N]"
# read -r answer
# if [[ "$answer" =~ ^[Yy]$ ]]; then
#     rm -rf "${PROJECT_DIR}"
#     info "Project directory removed"
# fi

info "===== Uninstallation completed ====="
echo ""
info "Note: virtual environment (${VENV_DIR}) and project directory (${PROJECT_DIR}) have been preserved."
info "To remove them manually, run: rm -rf ${VENV_DIR} ${PROJECT_DIR}"