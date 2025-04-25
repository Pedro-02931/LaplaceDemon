#!/bin/bash

MONITORED_FILES=(
    "/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
    "/sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw"
    "/sys/block/zram*/comp_algorithm"
    "/sys/class/zram-control/hot_add"
    "/proc/sys/vm/swappiness"
)

LOG_FILE="/var/log/urro_listener.log"
touch "$LOG_FILE"

echo "🔎 [$(date)] Listener iniciado." >> "$LOG_FILE"

# Constrói lista dos arquivos reais
WATCH_FILES=()
for pattern in "${MONITORED_FILES[@]}"; do
    for f in $pattern; do
        [[ -e "$f" ]] && WATCH_FILES+=("$f")
    done
done

# Roda o listener
inotifywait -m -e modify "${WATCH_FILES[@]}" 2>/dev/null | while read -r path action file; do
    echo "📌 [$(date)] $action em $path$file" >> "$LOG_FILE"
done
