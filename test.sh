#!/bin/bash

HISTORY_FILE="/tmp/urro_history"
MAX_HISTORY=10
CURRENT_POLICY_KEY=""

declare -A SAFE_LIMITS=( [CPU_TEMP]=85000 )
CRITICAL_TEMP_THRESHOLD=88000

load_intel_specs() {
    MAX_TDP=$(cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_max_power_uw 2>/dev/null | awk '{print $1/1000000}')
    MAX_GPU_CLOCK=$(cat /sys/class/drm/card0/gt_max_freq_mhz 2>/dev/null)
    CORES_TOTAL=$(nproc --all 2>/dev/null)

    MAX_TDP=${MAX_TDP:-15}
    MAX_GPU_CLOCK=${MAX_GPU_CLOCK:-1000}
    CORES_TOTAL=${CORES_TOTAL:-4}
}

load_intel_specs
declare -A HOLISTIC_POLICIES=(
    # Formato: "CPU Gov | Power Limit (%TDP) | TDP Limit (%TDP) | GPU Clock (%GPU_MAX) | | Algoritmo ZRAM | Streams | Swappiness"
    ["000"]="ondemand    $((MAX_TDP * 20 / 100)) $((MAX_TDP * 15 / 100)) $((MAX_GPU_CLOCK * 30 / 100)) zstd $((CORES_TOTAL * 25 / 100)) 10"
    ["010"]="ondemand    $((MAX_TDP * 25 / 100)) $((MAX_TDP * 18 / 100)) $((MAX_GPU_CLOCK * 35 / 100)) zstd $((CORES_TOTAL * 30 / 100)) 15"
    ["020"]="ondemand    $((MAX_TDP * 30 / 100)) $((MAX_TDP * 20 / 100)) $((MAX_GPU_CLOCK * 40 / 100)) lz4  $((CORES_TOTAL * 40 / 100)) 20"
    ["030"]="ondemand    $((MAX_TDP * 35 / 100)) $((MAX_TDP * 22 / 100)) $((MAX_GPU_CLOCK * 45 / 100)) lz4  $((CORES_TOTAL * 50 / 100)) 25"
    ["040"]="ondemand    $((MAX_TDP * 40 / 100)) $((MAX_TDP * 25 / 100)) $((MAX_GPU_CLOCK * 50 / 100)) lzo  $((CORES_TOTAL * 60 / 100)) 30"
    ["050"]="userspace   $((MAX_TDP * 50 / 100)) $((MAX_TDP * 30 / 100)) $((MAX_GPU_CLOCK * 60 / 100)) lz4  $((CORES_TOTAL * 70 / 100)) 35"
    ["060"]="userspace   $((MAX_TDP * 60 / 100)) $((MAX_TDP * 35 / 100)) $((MAX_GPU_CLOCK * 70 / 100)) lzo  $((CORES_TOTAL * 80 / 100)) 40"
    ["070"]="performance $((MAX_TDP * 70 / 100)) $((MAX_TDP * 40 / 100)) $((MAX_GPU_CLOCK * 80 / 100)) zstd $((CORES_TOTAL * 90 / 100)) 50"
    ["080"]="performance $((MAX_TDP * 90 / 100)) $((MAX_TDP * 50 / 100)) $((MAX_GPU_CLOCK * 90 / 100)) lz4  $((CORES_TOTAL)) 55"
    ["090"]="performance $((MAX_TDP * 95 / 100)) $((MAX_TDP * 55 / 100)) $((MAX_GPU_CLOCK * 95 / 100)) lz4  $((CORES_TOTAL)) 60"
    ["100"]="performance $((MAX_TDP))           $((MAX_TDP))           $((MAX_GPU_CLOCK))           zstd $((CORES_TOTAL)) 65"
)

get_cpu_usage() {
    local stat_hist_file="${HISTORY_FILE}.stat"
    local cpu_line=$(grep -E '^cpu ' /proc/stat)

    read -r _ last_user last_nice last_system last_idle last_iowait last_irq last_softirq _ _ < <(grep '^cpu ' "$stat_hist_file" 2> /dev/null || echo "cpu 0 0 0 0 0 0 0 0 0 0")
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

update_history_and_get_avg() {
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
    avg=$(update_history_and_get_avg "$usage")

    key=$(printf "%03d" $((avg / 10 * 10)))

    if [[ -v HOLISTIC_POLICIES["$key"] ]]; then
        echo "$key|$avg"
    else
        echo "000|$avg"
    fi
}

echo "🚀 Iniciando motor de cruzamento bayesiano..."

while true; do
    OUTPUT=$(determine_policy_key)
    POLICY_KEY="${OUTPUT%%|*}"
    AVG_CPU="${OUTPUT##*|}"
    POLICY="${HOLISTIC_POLICIES[$POLICY_KEY]}"

    echo -e "\n🔁 $(date) :: Chave: $POLICY_KEY :: Média CPU: ${AVG_CPU}%"
    echo -e "📦 Configuração de cruzamento:\n$POLICY"

    sleep 5
done
