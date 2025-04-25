#!/bin/bash

set -e

# Caminhos fixos
URRO_DIR="/opt/urro"
URRO_SCRIPT="$URRO_DIR/urro_engine.sh"
SERVICE_FILE="/etc/systemd/system/urro.service"
TIMER_FILE="/etc/systemd/system/urro.timer"

echo "🔧 Instalando motor URRO em $URRO_DIR..."

# Cria diretório
mkdir -p "$URRO_DIR"

# Cria o script principal com superpoderes
cat << 'EOF' > "$URRO_SCRIPT"
#!/bin/bash

set -e

HISTORY_FILE="/tmp/holistic_history"
MAX_HISTORY=10

load_intel_specs() {
    MAX_TDP=$(cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_max_power_uw 2>/dev/null | awk '{print $1/1000000}')
    MAX_GPU_CLOCK=$(cat /sys/class/drm/card0/gt_max_freq_mhz 2>/dev/null)
    CORES_TOTAL=$(nproc --all 2>/dev/null)

    MAX_TDP=${MAX_TDP:-15}
    MAX_GPU_CLOCK=${MAX_GPU_CLOCK:-1000}
    CORES_TOTAL=${CORES_TOTAL:-4}
}

declare -A HOLISTIC_POLICIES

init_policies() {
    HOLISTIC_POLICIES["000"]="ondemand $((MAX_TDP * 75 / 100)) $((MAX_TDP * 30 / 100)) zstd $((CORES_TOTAL * 25 / 100)) 10"
    HOLISTIC_POLICIES["010"]="ondemand $((MAX_TDP * 80 / 100)) $((MAX_TDP * 35 / 100)) zstd $((CORES_TOTAL * 30 / 100)) 15"
    HOLISTIC_POLICIES["020"]="ondemand $((MAX_TDP * 85 / 100)) $((MAX_TDP * 40 / 100)) lz4  $((CORES_TOTAL * 40 / 100)) 20"
    HOLISTIC_POLICIES["030"]="userspace $((MAX_TDP * 90 / 100)) $((MAX_TDP * 45 / 100)) lz4  $((CORES_TOTAL * 50 / 100)) 25"
    HOLISTIC_POLICIES["040"]="userspace $((MAX_TDP)) $((MAX_TDP)) lzo  $((CORES_TOTAL * 60 / 100)) 30"
    HOLISTIC_POLICIES["050"]="userspace $((MAX_TDP)) $((MAX_TDP)) lz4  $((CORES_TOTAL * 70 / 100)) 35"
    HOLISTIC_POLICIES["060"]="performance $((MAX_TDP)) $((MAX_TDP)) lzo  $((CORES_TOTAL * 80 / 100)) 40"
    HOLISTIC_POLICIES["070"]="performance $((MAX_TDP)) $((MAX_TDP)) zstd $((CORES_TOTAL * 90 / 100)) 50"
    HOLISTIC_POLICIES["080"]="performance $((MAX_TDP)) $((MAX_TDP)) lz4  $((CORES_TOTAL)) 55"
    HOLISTIC_POLICIES["090"]="performance $((MAX_TDP)) $((MAX_TDP)) lz4  $((CORES_TOTAL)) 60"
    HOLISTIC_POLICIES["100"]="performance $((MAX_TDP)) $((MAX_TDP)) zstd $((CORES_TOTAL)) 65"
}

faz_o_urro() {
    local new_val="$1"
    local -a history=()
    local sum=0 avg
    [[ -f "$HISTORY_FILE" ]] && mapfile -t history < "$HISTORY_FILE"
    history+=("$new_val")
    if (( ${#history[@]} > MAX_HISTORY )); then
        history=("${history[@]: -$MAX_HISTORY}")
    fi
    for val in "${history[@]}"; do
        sum=$((sum + val))
    done
    avg=$((sum / ${#history[@]}))
    printf "%s\n" "${history[@]}" > "$HISTORY_FILE"
    echo "$avg"
}

determine_policy_key() {
    local usage avg key
    usage=$(get_cpu_usage)
    avg=$(faz_o_urro "$usage")
    key=$(printf "%03d" $((avg / 10 * 10)))
    echo "$key|$avg"
}

get_cpu_usage() {
    local stat_hist_file="${HISTORY_FILE}.stat"
    local cpu_line=$(grep -E '^cpu ' /proc/stat)
    read -r _ last_user last_nice last_system last_idle last_iowait last_irq last_softirq _ _ < <(grep '^cpu ' "$stat_hist_file" 2>/dev/null || echo "cpu 0 0 0 0 0 0 0 0 0 0")
    read -r _ curr_user curr_nice curr_system curr_idle curr_iowait curr_irq curr_softirq _ _ < <(echo "$cpu_line")
    echo "$cpu_line" > "$stat_hist_file"
    local last_total=$((last_user + last_nice + last_system + last_idle + last_iowait + last_irq + last_softirq))
    local curr_total=$((curr_user + curr_nice + curr_system + curr_idle + curr_iowait + curr_irq + curr_softirq))
    local diff_idle=$((curr_idle - last_idle))
    local diff_total=$((curr_total - last_total))
    if (( diff_total > 0 )); then
        echo $(( (1000 * (diff_total - diff_idle) / diff_total + 5) / 10 ))
    else
        echo 0
    fi
}

apply_cpu_governor() {
    local cpu_gov="$1"
    local last_gov_file="/tmp/urro_last_gov"
    local last_gov=$(cat "$last_gov_file" 2>/dev/null || echo "none")
    
    # Só muda governor se diferente e passaram ≥30s desde última mudança
    if [[ "$cpu_gov" != "$last_gov" ]] && \
       [[ ! -f "/tmp/urro_gov_cooldown" || $(($(date +%s) - $(date -r "/tmp/urro_gov_cooldown" +%s))) -ge 30 ]]; then
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo "$cpu_gov" | tee "$cpu" > /dev/null
        done
        echo "$cpu_gov" > "$last_gov_file"
        touch "/tmp/urro_gov_cooldown"
    fi
}
apply_swappiness() {
    local swap="$1"
    sysctl -q -w vm.swappiness="$swap"
}

apply_tdp_limit() {
    local min_limit="$1"
    local max_limit="$2"
    local current_min=$(cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_1_power_limit_uw 2>/dev/null | awk '{print $1/1000000}')
    local current_max=$(cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw 2>/dev/null | awk '{print $1/1000000}')
    
    # Ajuste máximo: ±2W por ciclo para evitar transições abruptas
    (( min_limit = current_min + (min_limit - current_min > 0 ? 2 : -2) ))
    (( max_limit = current_max + (max_limit - current_max > 0 ? 2 : -2) ))
    
    (( min_limit > 0 )) && echo $((min_limit * 1000000)) | tee /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_1_power_limit_uw > /dev/null
    (( max_limit > 0 )) && echo $((max_limit * 1000000)) | tee /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw > /dev/null
}

apply_zram_algorithm() {
    local alg="$1"
    for zram in /sys/block/zram*/comp_algorithm; do
        [[ "$(cat "$zram" 2>/dev/null)" != "$alg" ]] && echo "$alg" | tee "$zram" > /dev/null
    done
}

apply_zram_streams() {
    local streams="$1"
    (( streams <= 0 )) && return
    
    # Só ajusta se número de streams mudar
    local current_streams=$(ls /dev/zram* 2>/dev/null | wc -l)
    if (( current_streams != streams )); then
        for dev in /dev/zram*; do
            [[ -e "$dev" ]] && swapoff "$dev" 2>/dev/null || true
        done
        sleep 1  # Pausa para o kernel respirar
        modprobe zram num_devices="$streams"
    fi
}

apply_all() {
    load_intel_specs
    init_policies
    IFS='|' read -r key avg <<< "$(determine_policy_key)"
    read -ra values <<< "${HOLISTIC_POLICIES[$key]}"
    echo "🔁 $(date) :: Média CPU: ${avg}% | Perfil: $key"
    echo "→ Governor: ${values[0]} | TDP_MIN: ${values[1]} | TDP_MAX: ${values[2]} | Alg ZRAM: ${values[3]} | Streams: ${values[4]} | Swappiness: ${values[5]}"
    apply_cpu_governor "${values[0]}"
    apply_tdp_limit "${values[1]}" "${values[2]}"
    apply_zram_algorithm "${values[3]}"
    apply_zram_streams "${values[4]}"
    apply_swappiness "${values[5]}"
}

apply_all
EOF

# Permissões restritas e root-only
chmod 700 "$URRO_SCRIPT"
chown root:root "$URRO_SCRIPT"

# Criação do service
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=URRO Engine - Motor de cruzamento bayesiano
After=multi-user.target

[Service]
Type=oneshot
ExecStart=$URRO_SCRIPT
EOF

# Criação do timer
cat <<EOF > "$TIMER_FILE"
[Unit]
Description=URRO Timer (cada 5 segundos)

[Timer]
OnBootSec=10
OnUnitActiveSec=5s
Unit=urro.service

[Install]
WantedBy=timers.target
EOF

# Ativando e inicializando
echo "🔌 Ativando serviço e timer..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable urro.timer
systemctl start urro.timer

echo "✅ Instalação concluída! O URRO já está rugindo!"
