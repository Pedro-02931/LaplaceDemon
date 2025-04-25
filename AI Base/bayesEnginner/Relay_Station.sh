#!/bin/bash

load_intel_specs() {
    MAX_TDP=$(cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_max_power_uw 2>/dev/null | awk '{print $1/1000000}')
    MAX_GPU_CLOCK=$(cat /sys/class/drm/card0/gt_max_freq_mhz 2>/dev/null)
    CORES_TOTAL=$(nproc --all 2>/dev/null)

    MAX_TDP=${MAX_TDP:-15}
    MAX_GPU_CLOCK=${MAX_GPU_CLOCK:-1000}
    CORES_TOTAL=${CORES_TOTAL:-4}
}

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

