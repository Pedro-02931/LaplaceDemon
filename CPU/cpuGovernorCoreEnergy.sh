#!/bin/bash

# =============================
# MONOLITO ZEN DO COLAPSO
# =============================

set -e

SERVICE_NAME="cpu-core-adjust"
SCRIPT_PATH="/usr/local/bin/${SERVICE_NAME}.sh"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
TIMER_FILE="/etc/systemd/system/${SERVICE_NAME}.timer"

log() {
    echo "[SETUP] $(date +%T) :: $1"
}

install_deps() {
    command -v wrmsr >/dev/null || {
        log "Instalando msr-tools..."
        sudo apt update && sudo apt install msr-tools -y
        sudo modprobe msr
    }
    command -v cpupower >/dev/null || {
        log "Instalando cpupower..."
        sudo apt install linux-tools-common linux-tools-$(uname -r) -y
    }
}

create_script() {
    sudo tee "$SCRIPT_PATH" > /dev/null << 'EOF'
#!/bin/bash
set -euo pipefail

log() {
    echo "[CPU-ZEN] $(date +%T) :: $1"
}

safe_core_control() {
    local desired=$1
    local total_cores=$(nproc --all)

    for (( cpu=0; cpu<total_cores; cpu++ )); do
        local state_file="/sys/devices/system/cpu/cpu$cpu/online"
        [[ -f "$state_file" ]] || continue
        local current=$(<"$state_file")
        if [[ $cpu -lt $desired && $current -eq 0 ]]; then
            echo 1 | sudo tee "$state_file" >/dev/null 2>&1
        elif [[ $cpu -ge $desired && $current -eq 1 ]]; then
            echo 0 | sudo tee "$state_file" >/dev/null 2>&1
        fi
    done
}

apply_energy_bias() {
    local epb="$1"
    local current=$(sudo rdmsr -r 0x1b0 2>/dev/null | awk '{ printf "%02X\n", $1 }') || return
    [[ "$current" != "$epb" ]] && sudo wrmsr -a 0x1b0 $((16#$epb)) 2>/dev/null || true
}

declare -A CPU_POLITICAS=(
    [0]=" 1 0A"
    [50]=" 2 0A"
    [75]=" 3 08"
    [100]=" 4 06"
)
THRESHOLDS=(0 50 75 100)

main() {
    local cpu_usage=$(awk -v idlep=$(top -bn2 | grep '%Cpu' | tail -1 | awk '{print $8}') 'BEGIN {print 100 - idlep}' | cut -d. -f1)
    cpu_usage=$((cpu_usage > 100 ? 100 : cpu_usage))

    local threshold=100
    for t in "${THRESHOLDS[@]}"; do
        if (( cpu_usage <= t )); then
            threshold=$t
            break
        fi
    done

    IFS=' ' read -r desired_cores desired_epb <<< "${CPU_POLITICAS[$threshold]}"

    local active_cores=$(grep -c '^1$' /sys/devices/system/cpu/cpu[0-9]*/online)
    local current_epb=$(sudo rdmsr -r 0x1b0 2>/dev/null | awk '{ printf "%02X\n", $1 }' || echo "FF")

    if [["$active_cores" -eq "$desired_cores" && "$current_epb" == "$desired_epb" ]]; then
        log "Parâmetros casados. Equilíbrio mantido."
        return
    fi

    log "Desequilíbrio detectado. Colapsando estado para ajuste..."
    safe_core_control 0
    sleep 0.5

    log "Aplicando estado ideal: Núcleos=$desired_cores | EPB=$desired_epb"
    safe_core_control "$desired_cores"
    apply_energy_bias "$desired_epb"
}

main
EOF

    sudo chmod +x "$SCRIPT_PATH"
    log "Script Zen criado em $SCRIPT_PATH"
}

create_service() {
    sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=CPU Core Auto Adjuster - Zen Mode

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
EOF

    log "Service criado em $SERVICE_FILE"
}

create_timer() {
    sudo tee "$TIMER_FILE" > /dev/null << EOF
[Unit]
Description=Timer para autoajuste de núcleos (Zen Collapse)

[Timer]
OnBootSec=30
OnUnitActiveSec=20

[Install]
WantedBy=timers.target
EOF

    log "Timer criado em $TIMER_FILE"
}

enable_and_start() {
    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl enable --now ${SERVICE_NAME}.timer
    log "Daemon Zen iniciado com sucesso. O ciclo começa."
}

### 🌿 EXECUÇÃO
install_deps
create_script
create_service
create_timer
enable_and_start
