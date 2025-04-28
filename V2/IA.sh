#!/bin/bash
set -euo pipefail

# Diretórios e arquivos
BASE_DIR="/etc/bayes_mem"
mkdir -p "$BASE_DIR"

HW_SPECS_FILE="$BASE_DIR/hw_specs.conf"
APPLY_LOGIC_FILE="$BASE_DIR/bayes_apply_logic.sh"
COLLECTOR_SCRIPT="$BASE_DIR/bayes_collector.sh"
APPLIER_SCRIPT="$BASE_DIR/bayes_applier.sh"
LOG_DIR="/var/log/bayes_mem"
mkdir -p "$LOG_DIR"

COLLECTOR_SERVICE_NAME="bayes_collector"
APPLIER_SERVICE_NAME="bayes_applier"

# --- Funções ---

collect_and_save_hw_specs() {
    local cores total_mem_mb available_gov max_tdp tdp_uw

    cores=$(nproc --all 2>/dev/null || echo 4)
    total_mem_mb=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 )) || 4096
    available_gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null || echo "ondemand userspace performance")

    tdp_uw=$(cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_max_power_uw 2>/dev/null || \
             cat /sys/class/powercap/intel-rapl-core/intel-rapl-core:0/constraint_0_max_power_uw 2>/dev/null)

    if [[ -n "$tdp_uw" && "$tdp_uw" -gt 0 ]]; then
        max_tdp=$(( tdp_uw / 1000000 ))
    else
        max_tdp=15
        echo "WARN: Falha ao ler TDP Max via Intel RAPL, usando default ${max_tdp}W." >&2
    fi

    echo "Salvando especificações de HW em ${HW_SPECS_FILE}..."
    cat << EOF > "$HW_SPECS_FILE"
# Hardware Specifications
HW_CORES_TOTAL=${cores}
HW_TOTAL_MEM_MB=${total_mem_mb}
HW_AVAILABLE_GOVERNORS="${available_gov}"
HW_MAX_TDP=${max_tdp}
EOF
    chmod 644 "$HW_SPECS_FILE"
}

create_systemd_units() {
    cat << EOF > "/etc/systemd/system/${COLLECTOR_SERVICE_NAME}.service"
[Unit]
Description=Bayesian CPU Collector
Documentation=file://${COLLECTOR_SCRIPT}

[Service]
Type=oneshot
ExecStart=${COLLECTOR_SCRIPT}
StandardOutput=null
StandardError=append:${LOG_DIR}/collector.err
EOF

    cat << EOF > "/etc/systemd/system/${COLLECTOR_SERVICE_NAME}.timer"
[Unit]
Description=Bayesian Collector Timer
Requires=${COLLECTOR_SERVICE_NAME}.service

[Timer]
Unit=${COLLECTOR_SERVICE_NAME}.service
OnBootSec=5s
OnUnitActiveSec=1s
AccuracySec=100ms

[Install]
WantedBy=timers.target
EOF

    cat << EOF > "/etc/systemd/system/${APPLIER_SERVICE_NAME}.service"
[Unit]
Description=Bayesian CPU Settings Applier
Documentation=file://${APPLIER_SCRIPT}

[Service]
Type=oneshot
ExecStart=${APPLIER_SCRIPT}
StandardOutput=append:${LOG_DIR}/applier.log
StandardError=append:${LOG_DIR}/applier.err

[Install]
WantedBy=multi-user.target
EOF

    cat << EOF > "/etc/systemd/system/${APPLIER_SERVICE_NAME}.timer"
[Unit]
Description=Bayesian Applier Timer
Requires=${APPLIER_SERVICE_NAME}.service

[Timer]
Unit=${APPLIER_SERVICE_NAME}.service
OnBootSec=1min
OnUnitActiveSec=15s

[Install]
WantedBy=timers.target
EOF
}

create_collector_script() {
    cat << 'EOF' > "$COLLECTOR_SCRIPT"
#!/bin/bash
set -e

HISTORY_FILE="/tmp/bayes_history"
TREND_LOG="/tmp/bayes_trend.log"
MAX_HISTORY=30

faz_o_urro() {
    local new_val="$1" history_arr=() sum=0 avg=0 count=0
    [[ -f "$HISTORY_FILE" ]] && mapfile -t history_arr < "$HISTORY_FILE"
    history_arr+=("$new_val")
    count=${#history_arr[@]}
    if (( count > MAX_HISTORY )); then
        history_arr=("${history_arr[@]: -$MAX_HISTORY}")
        count=$MAX_HISTORY
    fi
    for val in "${history_arr[@]}"; do sum=$((sum + val)); done
    (( count > 0 )) && avg=$((sum / count))
    printf "%s\n" "${history_arr[@]}" > "$HISTORY_FILE"
    echo "$avg"
}

get_cpu_usage() {
    local stat_hist_file="${HISTORY_FILE}.stat"
    local cpu_line prev_line last_total curr_total diff_idle diff_total usage=0

    cpu_line=$(grep -E '^cpu ' /proc/stat || echo "cpu 0 0 0 0 0 0 0 0 0 0")
    prev_line=$(cat "$stat_hist_file" 2>/dev/null || echo "cpu 0 0 0 0 0 0 0 0 0 0")
    echo "$cpu_line" > "$stat_hist_file"

    read -r _ p_user p_nice p_system p_idle p_iowait p_irq p_softirq _ _ <<< "$prev_line"
    read -r _ c_user c_nice c_system c_idle c_iowait c_irq c_softirq _ _ <<< "$cpu_line"

    last_total=$((p_user + p_nice + p_system + p_idle + p_iowait + p_irq + p_softirq))
    curr_total=$((c_user + c_nice + c_system + c_idle + c_iowait + c_irq + c_softirq))
    diff_idle=$((c_idle - p_idle))
    diff_total=$((curr_total - last_total))

    if (( diff_total > 0 )); then
        usage=$(awk -v dt="$diff_total" -v di="$diff_idle" 'BEGIN { printf "%.0f", (100 * (dt - di)) / dt }')
    fi
    (( usage < 0 )) && usage=0
    (( usage > 100 )) && usage=100
    echo "$usage"
}

current_usage=$(get_cpu_usage)
average_usage=$(faz_o_urro "$current_usage")

echo "$average_usage" > "$TREND_LOG"
exit 0
EOF

    chmod 700 "$COLLECTOR_SCRIPT"
}

create_apply_logic_file() {
    cat << 'EOF' > "$APPLY_LOGIC_FILE"
#!/bin/bash

BASEDIR="/etc/bayes_mem"
mkdir -p "$BASEDIR"

source "$BASEDIR/hw_specs.conf"
source "$BASEDIR/hw_specs.conf"

declare -A BAYES_POLICIES

init_policies() {
    [[ "$HW_AVAILABLE_GOVERNORS" == *performance* ]] && gov_p="performance" || gov_p="ondemand"
    [[ "$HW_AVAILABLE_GOVERNORS" == *userspace* ]] && gov_u="userspace" || gov_u="ondemand"
    [[ "$HW_AVAILABLE_GOVERNORS" == *ondemand* ]] && gov_o="ondemand" || gov_o="performance"

    tdp_max=$HW_MAX_TDP
    tdp_high=$(( (tdp_max * 90 + 99) / 100 ))
    tdp_low=$(( (tdp_max * 50 + 99) / 100 ))
    tdp_min=$(( (tdp_max * 30 + 99) / 100 ))

    streams_high=$HW_CORES_TOTAL
    streams_med=$(( (streams_high * 75 + 99) / 100 ))
    streams_low=$(( (streams_high * 50 + 99) / 100 ))

    BAYES_POLICIES["080"]="${gov_p} ${tdp_high} ${tdp_max} zstd ${streams_high} 60"
    BAYES_POLICIES["050"]="${gov_u} ${tdp_low} ${tdp_high} lz4 ${streams_med} 40"
    BAYES_POLICIES["000"]="${gov_o} ${tdp_min} ${tdp_low} lzo-rle ${streams_low} 30"
}

determine_policy_key_from_avg() {
    local avg_load=$1 key="000"
    if (( avg_load >= 80 )); then key="080"
    elif (( avg_load >= 50 )); then key="050"
    fi
    echo "$key"
}


# --- Application Functions ---
apply_cpu_governor() {
    local cpu_gov="$1"
    local last_gov_file="${BASEDIR}/last_gov"
    local cooldown_file="${BASEDIR}/gov_cooldown"

    # Garante que o diretório BASEDIR existe
    

    local last_gov="none"
    if [[ -f "$last_gov_file" ]]; then
        last_gov=$(cat "$last_gov_file")
    fi

    # Só muda governor se diferente e passaram ≥30s desde última mudança
if [[ "$cpu_gov" != "$last_gov" ]] && \
   [[ ! -f "$cooldown_file" || $(($(date +%s) - $(date -r "$cooldown_file" +%s))) -ge 10 ]]; then
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "$cpu_gov" | tee "$cpu" > /dev/null
done

    echo "$cpu_gov" > "$last_gov_file"
    touch "$cooldown_file"
fi

}

apply_tdp_limit() {
local min_limit="$1"
    local max_limit="$2"
    local last_power_file="${BASEDIR}/last_power"
    local cooldown_file="${BASEDIR}/power_cooldown"

    local current_min=$(cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_1_power_limit_uw 2>/dev/null | awk '{print $1/1000000}')
    local current_max=$(cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw 2>/dev/null | awk '{print $1/1000000}')

    # Carrega último min e max aplicados, se existirem
    local last_min=0
    local last_max=0
    if [[ -f "$last_power_file" ]]; then
        read last_min last_max < "$last_power_file"
    fi

    # Só aplica se mudou de verdade ou se cooldown passou
    if [[ "$min_limit" != "$last_min" || "$max_limit" != "$last_max" ]] && \
       [[ ! -f "$cooldown_file" || $(($(date +%s) - $(date -r "$cooldown_file" +%s))) -ge 15 ]]; then
        
        # Ajuste máximo: ±2W por ciclo para evitar transições abruptas
        (( min_limit = current_min + (min_limit - current_min > 0 ? 2 : -2) ))
        (( max_limit = current_max + (max_limit - current_max > 0 ? 2 : -2) ))

        (( min_limit > 0 )) && echo $((min_limit * 1000000)) | tee /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_1_power_limit_uw > /dev/null
        (( max_limit > 0 )) && echo $((max_limit * 1000000)) | tee /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw > /dev/null

        echo "$min_limit $max_limit" > "$last_power_file"
        touch "$cooldown_file"
    fi

}

apply_swappiness() {
    local target_swap="$1"
    local last_swap_file="${BASEDIR}/last_swappiness"
    local cooldown_file="${BASEDIR}/cooldown_swappiness"

    mkdir -p "$BASEDIR"

    local current_swap=60
    if [[ -f "$last_swap_file" ]]; then
        current_swap=$(cat "$last_swap_file")
    else
        current_swap=$(sysctl -n vm.swappiness 2>/dev/null || echo 60)
    fi

    # Só aplica se for diferente E cooldown passou
    if [[ "$current_swap" != "$target_swap" ]] && \
   [[ ! -f "$cooldown_file" || $(($(date +%s) - $(date -r "$cooldown_file" +%s))) -ge 25 ]]; then

    if sysctl -q -w vm.swappiness="$target_swap"; then
        echo "$target_swap" > "$last_swap_file"
        touch "$cooldown_file"
    else
        echo "WARN: Failed to set swappiness" >&2
    fi
fi

}


setup_zram_device() {
    local alg="$1"
    local streams="$2"
    local last_alg_file="${BASEDIR}/last_zram_algorithm"
    local last_streams_file="${BASEDIR}/last_zram_streams"
    local cooldown_file="${BASEDIR}/cooldown_zram"

    mkdir -p "$BASEDIR"

    local current_alg="none"
    local current_streams=0

    [[ -f "$last_alg_file" ]] && current_alg=$(cat "$last_alg_file")
    [[ -f "$last_streams_file" ]] && current_streams=$(cat "$last_streams_file")

    # Atualiza algoritmo se necessário e cooldown respeitado
    if [[ "$current_alg" != "$alg" ]] && \
       [[ ! -f "$cooldown_file" || $(($(date +%s) - $(date -r "$cooldown_file" +%s))) -ge 35 ]]; then

        for zram in /sys/block/zram*/comp_algorithm; do
            echo "$alg" | tee "$zram" > /dev/null
        done
        echo "$alg" > "$last_alg_file"
        touch "$cooldown_file"
    fi

    # Atualiza número de streams se necessário
    if (( streams > 0 )) && (( current_streams != streams )) && \
       [[ ! -f "$cooldown_file" || $(($(date +%s) - $(date -r "$cooldown_file" +%s))) -ge 30 ]]; then

        for dev in /dev/zram*; do
            [[ -e "$dev" ]] && swapoff "$dev" 2>/dev/null || true
        done
        sleep 1  # Kernel precisa respirar
        modprobe -r zram 2>/dev/null || true
        modprobe zram num_devices="$streams"

        echo "$streams" > "$last_streams_file"
        touch "$cooldown_file"
    fi
}

apply_all_from_avg() {
    local avg_cpu_load=$1

    init_policies

    local key=$(determine_policy_key_from_avg "$avg_cpu_load")
    local policy="${BAYES_POLICIES[$key]}"

    if [[ -z "$policy" ]]; then
        echo "ERROR: Policy not found!" >&2
        exit 1
    fi

    read -r gov tdp_min tdp_max z_algo z_streams swapness <<< "$policy"

    echo "🔁 $(date) :: Média CPU: ${avg_cpu_load}% | Perfil: $key"
    echo "→ Governor: ${gov} | TDP_MIN: ${tdp_min} | TDP_MAX: ${tdp_max} | Alg ZRAM: ${z_algo} | Streams: ${z_streams} | Swappiness: ${swapness}"

    apply_cpu_governor "$gov"
    apply_tdp_limit "$tdp_min" "$tdp_max"
   setup_zram_device "$z_algo" "$z_streams"
    apply_swappiness "$swapness"
}

EOF

    chmod 700 "$APPLY_LOGIC_FILE"
}

create_applier_script() {
    cat << 'EOF' > "$APPLIER_SCRIPT"
#!/bin/bash
set -e

APPLY_LOGIC_FILE="/etc/bayes_mem/bayes_apply_logic.sh"
TREND_LOG="/tmp/bayes_trend.log"

source "$APPLY_LOGIC_FILE"

if [[ ! -f "$TREND_LOG" ]]; then
    echo "ERROR: No trend log found!" >&2
    exit 1
fi

avg=$(cat "$TREND_LOG")
apply_all_from_avg "$avg"
EOF

    chmod 700 "$APPLIER_SCRIPT"
}

# --- Execução dos criadores ---
collect_and_save_hw_specs
create_systemd_units
create_collector_script
create_apply_logic_file
create_applier_script

systemctl daemon-reload
systemctl enable "${COLLECTOR_SERVICE_NAME}.timer"
systemctl enable "${APPLIER_SERVICE_NAME}.timer"

echo "✅ Instalação concluída."
