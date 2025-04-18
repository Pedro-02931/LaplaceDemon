#!/bin/bash
#
# 🚀 energia-otimizador-installer.sh – Instalador do Controle Térmico/Energético
#

set -euo pipefail

SCRIPT_PATH="/usr/local/bin/energia-otimizador.sh"
SERVICE_PATH="/etc/systemd/system/energia-otimizador.service"
TIMER_PATH="/etc/systemd/system/energia-otimizador.timer"

log()   { echo "[INFO]  $(date '+%Y-%m-%d %H:%M:%S') $*"; }
warn()  { echo "[WARN]  $(date '+%Y-%m-%d %H:%M:%S') $*"; }
error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*"; }

[[ $EUID -ne 0 ]] && { error "Execute como root."; exit 1; }

log "Criando script de otimização em $SCRIPT_PATH"

cat << 'EOF' > "$SCRIPT_PATH"
#!/bin/bash
set -euo pipefail

TLP_CONF="/etc/tlp.conf"

log()   { echo "[INFO]  $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "/var/log/energia-otimizador.log"; }
warn()  { echo "[WARN]  $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "/var/log/energia-otimizador.log"; }
error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "/var/log/energia-otimizador.log"; }

check_dependencies() {
    local missing=()
    command -v tlp >/dev/null || missing+=("tlp")
    command -v sensors >/dev/null || missing+=("lm-sensors")
    command -v stress-ng >/dev/null || missing+=("stress-ng")
    if [ ${#missing[@]} -gt 0 ]; then
        warn "Dependências faltando: ${missing[*]}"
        apt-get update && apt-get install -y "${missing[@]}" || error "Falha na instalação"
        systemctl enable --now tlp 2>/dev/null || true
        sensors-detect --auto 2>/dev/null || true
    fi
}

get_system_status() {
    CPU_TEMP=$(sensors -u coretemp-isa-0 2>/dev/null | awk '/input/ {sum+=$2; cnt++} END {printf "%d", (cnt>0)?sum/cnt:40}')
    if [[ -f /sys/class/power_supply/AC/online ]]; then
        POWER_STATE=$( (grep -q 1 /sys/class/power_supply/AC/online && echo "AC") || echo "BAT" )
    else
        local battery_path=$(upower -e 2>/dev/null | grep -m1 battery || echo "")
        [[ -n "$battery_path" ]] && POWER_STATE=$(upower -i "$battery_path" | awk -F: '/state/ {print $2}' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
        [[ "$POWER_STATE" == *discharging* ]] && POWER_STATE="BAT" || POWER_STATE="AC"
    fi
    CPU_MAX_TEMP=$(sensors -u coretemp-isa-0 2>/dev/null | awk '/temp1_max/ {temp=$2} END {printf "%d", (temp+0)?temp:95}')
    BAT_CAPACITY=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1 || echo "100")
}

radio_control() {
    local policy=$1
    case $policy in
        off)  tlp-rdw block all >/dev/null; rfkill block wwan bluetooth >/dev/null ;;
        low)  tlp-rdw unblock wifi >/dev/null; rfkill block wwan bluetooth >/dev/null ;;
        high) tlp-rdw unblock all >/dev/null; rfkill unblock all >/dev/null ;;
    esac
}

declare -A ENERGY_PROFILES=(
    ["35"]="powersave battery 128 1 off"
    ["55"]="ondemand balanced 192 0 low"
    ["75"]="performance performance 254 0 high"
    ["90"]="performance performance 254 0 off"
)

check_collapse() {
    local desired_gov=$1 desired_gpu=$2 desired_disk=$3 desired_usb=$4 desired_radio=$5
    local current_gov=$(tlp-stat -c | awk -F'=' '/CPU_SCALING_GOVERNOR/ {print $2}' | tr -d '"')
    local current_gpu=$(tlp-stat -c | awk -F'=' '/RADEON_DPM_STATE/ {print $2}' | tr -d '"')
    local current_disk=$(tlp-stat -c | awk -F'=' '/SATA_LINKPWR/ {print $2}' | tr -d '"')
    local current_usb=$(tlp-stat -c | awk -F'=' '/USB_AUTOSUSPEND/ {print $2}' | tr -d '"')
    local current_radio=$(tlp-rdw status | awk '/Bluetooth|WWAN/ {print $3}' | tr '\n' ' ')
    [[ "$current_gov" == "$desired_gov" ]] && [[ "$current_gpu" == "$desired_gpu" ]] && [[ "$current_disk" == "$desired_disk" ]] && [[ "$current_usb" == "$desired_usb" ]] && [[ "$current_radio" == *"$desired_radio"* ]]
}

apply_energy_profile() {
    local threshold=$1
    IFS=" " read -r cpu_gov gpu_mode disk_apm usb_suspend radio_pol <<< "${ENERGY_PROFILES[$threshold]}"
    if check_collapse "$cpu_gov" "$gpu_mode" "$disk_apm" "$usb_suspend" "$radio_pol"; then
        log "Colapso de estado: Configuração $threshold% já ativa → mantida"
        return 0
    fi
    log "Aplicando Perfil ${threshold}% TjMax:"
    log "→ CPU: $cpu_gov | GPU: $gpu_mode | Disco: $disk_apm | USB: $usb_suspend | Rádio: $radio_pol"
    if [[ "$POWER_STATE" == "AC" ]]; then
        tlp ac --CPU_SCALING_GOVERNOR_ON_AC="$cpu_gov" --RADEON_DPM_STATE_ON_AC="$gpu_mode" --SATA_LINKPWR_ON_AC="max_performance" --USB_AUTOSUSPEND="$usb_suspend"
    else
        tlp bat --CPU_SCALING_GOVERNOR_ON_BAT="$cpu_gov" --RADEON_DPM_STATE_ON_BAT="$gpu_mode" --SATA_LINKPWR_ON_BAT="$disk_apm" --USB_AUTOSUSPEND="$usb_suspend" --CPU_MIN_PERF_ON_BAT=$((BAT_CAPACITY > 20 ? BAT_CAPACITY/2 : 10)) --CPU_MAX_PERF_ON_BAT=$BAT_CAPACITY
    fi
    radio_control "$radio_pol"
    tlp start >/dev/null
    return 1
}

main() {
    check_dependencies
    get_system_status
    if systemctl list-unit-files | grep -q '^thermald.service'; then
        systemctl restart thermald 2>/dev/null || warn "Thermald não iniciado"
    fi
    systemctl restart tlp 2>/dev/null || true
    local pct=$(( CPU_TEMP * 100 / CPU_MAX_TEMP ))
    local thresholds=($(printf '%s\n' "${!ENERGY_PROFILES[@]}" | sort -n))
    local selected_threshold=${thresholds[-1]}
    for th in "${thresholds[@]}"; do
        if (( pct <= th )); then
            selected_threshold=$th
            break
        fi
    done
    apply_energy_profile "$selected_threshold" || true
}

main
EOF

chmod +x "$SCRIPT_PATH"

log "Criando service e timer do systemd"

cat << EOF > "$SERVICE_PATH"
[Unit]
Description=Energia Otimizador
After=network.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > "$TIMER_PATH"
[Unit]
Description=Energia Otimizador Timer

[Timer]
OnBootSec=2min
OnUnitActiveSec=10min
Unit=energia-otimizador.service

[Install]
WantedBy=timers.target
EOF

log "Recarregando systemd e habilitando serviço/timer"
systemctl daemon-reload
systemctl enable --now energia-otimizador.timer

log "Instalação concluída."
