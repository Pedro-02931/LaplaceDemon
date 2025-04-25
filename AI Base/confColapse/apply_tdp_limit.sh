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

