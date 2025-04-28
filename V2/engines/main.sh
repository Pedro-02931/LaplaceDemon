#!/bin/bash

# Strict mode
set -euo pipefail

# Define fixed paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_BASE_DIR="/etc/bayes_mem"
SCRIPT_DIR="/usr/local/sbin/bayes_mem"
LOG_DIR="/var/log/bayes_mem"
HW_SPECS_FILE="${CONFIG_BASE_DIR}/hw_specs.conf"
APPLY_LOGIC_FILE="${CONFIG_BASE_DIR}/bayes_apply_logic.sh"
COLLECTOR_SCRIPT="${SCRIPT_DIR}/bayes_collector.sh"
APPLIER_SCRIPT="${SCRIPT_DIR}/bayes_applier.sh"
COLLECTOR_SERVICE_NAME="bayes_collector"
APPLIER_SERVICE_NAME="bayes_mem" # Keep old name for applier consistency
TREND_LOG="/tmp/bayes_trend.log"
HISTORY_FILE="/tmp/bayes_history" # History for moving average

# --- Function Definitions ---

install_deps() {
    # Instala dependências essenciais, remove tuned se não for mais usado
    apt-get update
    apt-get install -y lm-sensors bc zram-tools util-linux coreutils gawk grep sed powercap-utils
    # apt-get remove -y tuned # Opcional: remover tuned se não usar mais
}

create_dirs() {
    mkdir -p "$CONFIG_BASE_DIR"
    mkdir -p "$SCRIPT_DIR"
    mkdir -p "$LOG_DIR"
    chmod 700 "$LOG_DIR"
}

source "$BASE_DIR/engine/init.IA"

# Importa o script init.IA usando o caminho relativo ao script principal
source "$BASE_DIR/engine/init"
source "$BASE_DIR/engine/create_apply_logic_file"
source "$BASE_DIR/engine/create_collector_script"
source "$BASE_DIR/engine/create_applier_script"
source "$BASE_DIR/engine/create_systemd_units"

# --- Main Execution Block ---
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root." >&2
   exit 1
fi

echo "Starting Bayesian System Setup (Collector + Applier)..."
install_deps
create_dirs
collect_and_save_hw_specs
create_apply_logic_file
create_collector_script
create_applier_script
create_systemd_units

echo "Reloading systemd daemon, enabling and starting timers..."
systemctl daemon-reload
# Enable and start both timers
systemctl enable "${COLLECTOR_SERVICE_NAME}.timer"
systemctl start "${COLLECTOR_SERVICE_NAME}.timer"
systemctl enable "${APPLIER_SERVICE_NAME}.timer"
systemctl start "${APPLIER_SERVICE_NAME}.timer"

echo "Setup complete."
echo "Collector Timer status: $(systemctl is-active ${COLLECTOR_SERVICE_NAME}.timer)"
echo "Applier Timer status: $(systemctl is-active ${APPLIER_SERVICE_NAME}.timer)"
exit 0
