# Função para verificar e aplicar o governador da CPU
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

# Função para verificar e aplicar o TDP máximo permitido
apply_tdp_limit() {
    local tdp_limit="$1" # Valor em watts
    local current_tdp_limit
    current_tdp_limit=$(<"/sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw")
    current_tdp_limit=$((current_tdp_limit / 1000000)) # Converte para watts
    if [[ "$current_tdp_limit" != "$tdp_limit" ]]; then
        echo $((tdp_limit * 1000000)) | sudo tee /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw > /dev/null
        echo "✔️ TDP atualizado para $tdp_limit W"
    else
        echo "⚙️ TDP já está configurado como $tdp_limit W"
    fi
}

# Função para verificar e aplicar o swappiness
apply_swappiness() {
    local swappiness="$1"
    local current_swappiness
    current_swappiness=$(sysctl vm.swappiness | awk '{print $3}')
    if [[ "$current_swappiness" != "$swappiness" ]]; then
        sudo sysctl vm.swappiness="$swappiness" > /dev/null
        echo "✔️ Swappiness atualizado para $swappiness"
    else
        echo "⚙️ Swappiness já está configurado como $swappiness"
    fi
}