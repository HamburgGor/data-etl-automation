#!/bin/bash
# ==============================================
# ETL Auto Service Deploy & Update Script
# Features:
#   - systemd service with auto-restart
#   - cron health check (NO server reboot)
#   - data lifecycle demo: generation + cleanup every 2 min
#   - auto install dependencies (python3, pandas, openpyxl)
#   - clean obsolete services
#   - support for multiple Python scripts
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
    error "Please run this script with root privilege (sudo ./deploy.sh)"
fi

# ===================== Global Config =====================
if [ -n "${SUDO_USER:-}" ]; then
    RUN_USER="${SUDO_USER}"
else
    RUN_USER="$(whoami)"
fi

USER_HOME="/home/${RUN_USER}"
PROJECT_DIR="${USER_HOME}/data-etl-automation"
VENV_DIR="${USER_HOME}/Myvenv"
LOG_DIR="${USER_HOME}/logs"
SERVICE_PREFIX="etl_auto"
SYSTEMD_DIR="/etc/systemd/system"
PYTHON_BIN="${VENV_DIR}/bin/python3"
PIP_BIN="${VENV_DIR}/bin/pip"

SYS_DEPENDENCIES=("python3" "python3-pip" "python3-venv")
PY_DEPENDENCIES=("pandas" "openpyxl")
PYTHON_SCRIPTS=("${PROJECT_DIR}/main.py")

# ===================== Step 0: Clean previous deployment =====================
log "Cleaning up previous deployment (if any)..."
# Stop & remove existing services that match our prefix
for svc in $(systemctl list-unit-files --no-legend | grep "^${SERVICE_PREFIX}_" | awk '{print $1}'); do
    systemctl stop "${svc}" 2>/dev/null || true
    systemctl disable "${svc}" 2>/dev/null || true
    rm -f "${SYSTEMD_DIR}/${svc}"
done
# Remove old start scripts
rm -f "${USER_HOME}/start_"*.sh
# Remove old project-specific cron files
rm -f /etc/cron.d/etl_check_* /etc/cron.d/etl_data_lifecycle 2>/dev/null || true
# Clean root's crontab from periodic reboot entries
crontab -l 2>/dev/null | grep -v "Periodic reboot" | crontab - 2>/dev/null || true
log "Cleanup completed"

# ===================== Step 1: Install system packages =====================
log "Check & install system runtime packages"
apt update -qq
for pkg in "${SYS_DEPENDENCIES[@]}"; do
    if ! dpkg -l | grep -q "^ii  ${pkg} "; then
        log "Installing missing system package: ${pkg}"
        apt install -y "${pkg}" -qq
    fi
done
info "System packages check completed"

# ===================== Step 2: Virtual environment =====================
log "Check virtual environment: ${VENV_DIR}"
if [ ! -d "${VENV_DIR}" ]; then
    log "Creating new virtual environment"
    python3 -m venv "${VENV_DIR}"
fi
source "${VENV_DIR}/bin/activate"
log "Upgrade pip"
${PIP_BIN} install --upgrade pip -qq

# ===================== Step 3: Install Python dependencies =====================
log "Check & install Python dependencies..."
for dep in "${PY_DEPENDENCIES[@]}"; do
    if ! ${PYTHON_BIN} -c "import ${dep}" &>/dev/null; then
        log "Installing Python package: ${dep}"
        ${PIP_BIN} install "${dep}" -qq
    fi
done
info "All Python dependencies check completed"

# ===================== Step 4: Create directories =====================
log "Initialize directory structure"
mkdir -p "${LOG_DIR}" || error "Failed to create log directory"
mkdir -p "${PROJECT_DIR}/demo_data" "${PROJECT_DIR}/output" || error "Failed to create project subdirectories"
chown -R "${RUN_USER}:${RUN_USER}" "${PROJECT_DIR}" "${LOG_DIR}"
chmod -R 755 "${PROJECT_DIR}"

# Verify Python interpreter
if [ ! -x "${PYTHON_BIN}" ]; then
    error "Python interpreter not found: ${PYTHON_BIN}"
fi
python_version=$("${PYTHON_BIN}" --version 2>&1)
log "Python version: ${python_version}"

# Global deploy log
TOTAL_LOG="${LOG_DIR}/etl_deploy_update.log"
> "${TOTAL_LOG}"
log "Start ETL service deploy / update process" | tee -a "${TOTAL_LOG}"

# ===================== Step 5: Clean obsolete services (dynamic scan) =====================
log "Scan existing ETL services"
deployed_services=()
for service_file in "${SYSTEMD_DIR}/${SERVICE_PREFIX}_"*.service; do
    if [ -f "${service_file}" ]; then
        service_name=$(basename "${service_file}" .service)
        deployed_services+=("${service_name}")
    fi
done

current_services=()
for script_path in "${PYTHON_SCRIPTS[@]}"; do
    script_name=$(basename "${script_path}" .py)
    current_service="${SERVICE_PREFIX}_${script_name}"
    current_services+=("${current_service}")
done

info "===== Step 5: Clean obsolete services =====" | tee -a "${TOTAL_LOG}"
for deployed_service in "${deployed_services[@]}"; do
    if ! [[ " ${current_services[@]} " =~ " ${deployed_service} " ]]; then
        info "Removing obsolete service: ${deployed_service}" | tee -a "${TOTAL_LOG}"
        systemctl stop "${deployed_service}" 2>/dev/null || true
        systemctl disable "${deployed_service}" 2>/dev/null || true
        rm -f "${SYSTEMD_DIR}/${deployed_service}.service"
        script_name="${deployed_service#${SERVICE_PREFIX}_}"
        rm -f "${USER_HOME}/start_${script_name}.sh"
    fi
done

# ===================== Step 6: Deploy / Update services =====================
info "===== Step 6: Deploy ETL resident services =====" | tee -a "${TOTAL_LOG}"
for script_path in "${PYTHON_SCRIPTS[@]}"; do
    script_name=$(basename "${script_path}" .py)
    current_service="${SERVICE_PREFIX}_${script_name}"
    start_script="${USER_HOME}/start_${script_name}.sh"
    log_file="${LOG_DIR}/${script_name}_run.log"
    service_file="${SYSTEMD_DIR}/${current_service}.service"

    if [ ! -f "${script_path}" ]; then
        error "Python script not found: ${script_path}" | tee -a "${TOTAL_LOG}"
    fi

    # Generate start script
    cat > "${start_script}" << EOF
#!/bin/bash
set -euo pipefail
VENV_DIR="${VENV_DIR}"
LOG_FILE="${log_file}"
PY_SCRIPT="${script_path}"
PY_BIN="${VENV_DIR}/bin/python3"

log() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" >> "\${LOG_FILE}"
}
> "\${LOG_FILE}"
log "ETL startup script running"
log "Python interpreter: \${PY_BIN}"
log "Execute script: \${PY_SCRIPT}"

if ! "\${PY_BIN}" -c "import pandas" &>/dev/null; then
    log "FATAL: Missing dependency pandas"
    echo -e "${RED}[ERROR] Missing pandas${NC}" >&2
    exit 1
fi
exec "\${PY_BIN}" "\${PY_SCRIPT}" 2>> "\${LOG_FILE}"
EOF
    chmod +x "${start_script}"
    chown "${RUN_USER}:${RUN_USER}" "${start_script}"

    # Generate systemd service file
    cat > "${service_file}" << EOF
[Unit]
Description=Data ETL Auto Service - ${script_name}
After=network.target

[Service]
User=${RUN_USER}
Group=${RUN_USER}
Type=exec
ExecStart=${start_script}
WorkingDirectory=${PROJECT_DIR}
Restart=on-failure
RestartSec=60
StartLimitBurst=6
StartLimitIntervalSec=3600
TimeoutStartSec=90

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "${current_service}" || error "Failed to enable ${current_service}"
    systemctl restart "${current_service}" || error "Failed to start ${current_service}"
    
    if systemctl is-active --quiet "${current_service}"; then
        info "Service ${current_service} is running" | tee -a "${TOTAL_LOG}"
    else
        error "Service ${current_service} failed to start, check log: ${log_file}" | tee -a "${TOTAL_LOG}"
    fi
done

# ===================== Step 7: Cron tasks =====================
info "===== Step 7: Register cron jobs =====" | tee -a "${TOTAL_LOG}"

# Health check (07:50 and 19:50 daily)
etl_service_name="${SERVICE_PREFIX}_main"
cat > "/etc/cron.d/etl_check_${etl_service_name}" << EOF
50 07,19 * * * root systemctl is-active --quiet ${etl_service_name} || (echo "[\$(date +\%Y-\%m-\%d\ \%H:\%M:\%S)] Service down, restarting" >> ${LOG_DIR}/cron_check_${etl_service_name}.log; systemctl start ${etl_service_name} 2>> ${LOG_DIR}/cron_check_${etl_service_name}.log)
EOF
chmod 644 "/etc/cron.d/etl_check_${etl_service_name}"
log "Registered health check cron for ${etl_service_name}"

# Data generation & cleanup (every 2 minutes)
cat > /etc/cron.d/etl_data_lifecycle << EOF
*/2 * * * * ${RUN_USER} cd ${PROJECT_DIR} && ${PYTHON_BIN} gen_test_data.py >> ${LOG_DIR}/gen.log 2>&1
*/2 * * * * root cd ${PROJECT_DIR} && /bin/bash scripts/cleanup_old.sh >> ${LOG_DIR}/cleanup.log 2>&1
EOF
chmod 644 /etc/cron.d/etl_data_lifecycle
log "Registered data generation & cleanup cron (every 2 min)"

# ===================== Step 8: Final permissions fix =====================
chown -R "${RUN_USER}:${RUN_USER}" "${PROJECT_DIR}" "${LOG_DIR}"

# ===================== Final Status =====================
info "===== Deploy process finished, current service status =====" | tee -a "${TOTAL_LOG}"
for srv in "${current_services[@]}"; do
    status=$(systemctl is-active "${srv}" 2>/dev/null || echo "Not running")
    echo "  ${srv} : ${status}" | tee -a "${TOTAL_LOG}"
done

info "Schedule summary:" | tee -a "${TOTAL_LOG}"
info "1. Service monitor: 07:50 / 19:50 every day, auto restart if down" | tee -a "${TOTAL_LOG}"
info "2. Data lifecycle: new CSV every 2 min, cleanup files older than 5 virtual days" | tee -a "${TOTAL_LOG}"
info "3. Service restart policy: retry per 60s, max 6 times in 1 hour" | tee -a "${TOTAL_LOG}"
info "4. ETL service enabled auto start after system reboot" | tee -a "${TOTAL_LOG}"
log "ETL deploy / update process done!"