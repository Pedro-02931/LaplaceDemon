apply_cpu_governor() {
    local cpu_gov="$1"
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        local current_cpu_gov
        current_cpu_gov=$(<"$cpu")
        if [[ "$current_cpu_gov" != "$cpu_gov" ]]; then
            echo "$cpu_gov" | sudo tee "$cpu" > /dev/null
            echo "✔️ Governor atualizado para $cpu_gov"
        else
            echo "⚙️ Governor já está configurado como $cpu_gov"
        fi
    done
}
