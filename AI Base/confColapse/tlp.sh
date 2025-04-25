apply_tlp_config() {
    local cpu_gov="$1"       # Governador da CPU (ex: powersave, performance)
    local max_perf="$2"      # Frequência máxima da CPU em % (ex: 100)
    local min_perf="$3"      # Frequência mínima da CPU em % (ex: 20)
    local swappiness="$4"    # Valor de swappiness (ex: 10)
    local state_file="/var/optEnergy/tlp_config"  # Arquivo para armazenar o estado atual
    local current_state
    local new_state

    # Gera o estado atual baseado nos argumentos
    new_state="${cpu_gov}_${max_perf}_${min_perf}_${swappiness}"

    # Verifica se o estado atual já foi salvo
    if [[ -f "$state_file" ]]; then
        current_state=$(<"$state_file")
        if [[ "$current_state" == "$new_state" ]]; then
            echo "Configuração do TLP já está aplicada. Nenhuma alteração necessária."
            return
        fi
    fi

    # Caminho do arquivo de configuração do TLP
    local tlp_config="/etc/tlp.conf"

    # Verifica se o arquivo de configuração do TLP existe
    if [[ ! -f "$tlp_config" ]]; then
        echo "Erro: Arquivo de configuração do TLP não encontrado em $tlp_config."
        return 1
    fi

    echo "Aplicando configurações do TLP..."

    # Configura o governador da CPU apenas se necessário
    local current_cpu_gov
    current_cpu_gov=$(grep "^CPU_SCALING_GOVERNOR_ON_AC=" "$tlp_config" | cut -d'=' -f2 | tr -d '"')
    if [[ "$current_cpu_gov" != "$cpu_gov" ]]; then
        sudo sed -i "s/^CPU_SCALING_GOVERNOR_ON_AC=.*/CPU_SCALING_GOVERNOR_ON_AC=\"$cpu_gov\"/" "$tlp_config"
        sudo sed -i "s/^CPU_SCALING_GOVERNOR_ON_BAT=.*/CPU_SCALING_GOVERNOR_ON_BAT=\"$cpu_gov\"/" "$tlp_config"
    fi

    # Configura a frequência máxima e mínima da CPU apenas se necessário
    local current_max_perf current_min_perf
    current_max_perf=$(grep "^CPU_MAX_PERF_ON_AC=" "$tlp_config" | cut -d'=' -f2)
    current_min_perf=$(grep "^CPU_MIN_PERF_ON_AC=" "$tlp_config" | cut -d'=' -f2)
    if [[ "$current_max_perf" != "$max_perf" ]]; then
        sudo sed -i "s/^CPU_MAX_PERF_ON_AC=.*/CPU_MAX_PERF_ON_AC=$max_perf/" "$tlp_config"
        sudo sed -i "s/^CPU_MAX_PERF_ON_BAT=.*/CPU_MAX_PERF_ON_BAT=$max_perf/" "$tlp_config"
    fi
    if [[ "$current_min_perf" != "$min_perf" ]]; then
        sudo sed -i "s/^CPU_MIN_PERF_ON_AC=.*/CPU_MIN_PERF_ON_AC=$min_perf/" "$tlp_config"
        sudo sed -i "s/^CPU_MIN_PERF_ON_BAT=.*/CPU_MIN_PERF_ON_BAT=$min_perf/" "$tlp_config"
    fi

    # Configura o swappiness apenas se necessário
    local current_swappiness
    current_swappiness=$(grep "^VM_SWAPPINESS=" "$tlp_config" | cut -d'=' -f2)
    if [[ "$current_swappiness" != "$swappiness" ]]; then
        sudo sed -i "s/^VM_SWAPPINESS=.*/VM_SWAPPINESS=$swappiness/" "$tlp_config"
    fi

    # Reinicia o TLP para aplicar as mudanças
    sudo systemctl restart tlp

    # Salva o novo estado no arquivo
    echo "$new_state" | sudo tee "$state_file" > /dev/null
    echo "Configurações do TLP aplicadas com sucesso:"
    echo "  CPU Governor: $cpu_gov"
    echo "  CPU Max Perf: $max_perf%"
    echo "  CPU Min Perf: $min_perf%"
    echo "  Swappiness: $swappiness"
}