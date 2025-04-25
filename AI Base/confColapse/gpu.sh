apply_gpu_clock() {
    local gpu_clock="$1"
    local state_file="/var/optEnergy/gpu_clock"  # Arquivo para armazenar o estado atual
    local current_state
    local new_state

    # Gera o estado atual baseado no clock da GPU
    new_state="$gpu_clock"

    # Verifica se o estado atual já foi salvo
    if [[ -f "$state_file" ]]; then
        current_state=$(<"$state_file")
        if [[ "$current_state" == "$new_state" ]]; then
            echo "Configuração de GPU Clock '$gpu_clock MHz' já está aplicada. Nenhuma alteração necessária."
            return
        fi
    fi

    # Aplica o clock máximo da GPU apenas se necessário
    local boost_file="/sys/class/drm/card0/gt_boost_freq_mhz"
    local max_file="/sys/class/drm/card0/gt_max_freq_mhz"

    if [[ -f "$boost_file" ]]; then
        local current_boost_clock
        current_boost_clock=$(<"$boost_file")
        if [[ "$current_boost_clock" != "$gpu_clock" ]]; then
            echo "$gpu_clock" | sudo tee "$boost_file" > /dev/null
        fi
    else
        echo "Erro: Arquivo $boost_file não encontrado."
        return 1
    fi

    if [[ -f "$max_file" ]]; then
        local current_max_clock
        current_max_clock=$(<"$max_file")
        if [[ "$current_max_clock" != "$gpu_clock" ]]; then
            echo "$gpu_clock" | sudo tee "$max_file" > /dev/null
        fi
    else
        echo "Erro: Arquivo $max_file não encontrado."
        return 1
    fi

    # Salva o novo estado no arquivo
    echo "$new_state" | sudo tee "$state_file" > /dev/null
    echo "Configuração de GPU Clock '$gpu_clock MHz' aplicada com sucesso."
}