apply_cpu_governor() {
    local governor="$1"
    local state_file="/var/optEnergy/cpu_governor"  # Arquivo para armazenar o estado atual
    local current_state
    local new_state

    # Gera o estado atual baseado no governador
    new_state="$governor"

    # Verifica se o estado atual já foi salvo
    if [[ -f "$state_file" ]]; then
        current_state=$(<"$state_file")
        if [[ "$current_state" == "$new_state" ]]; then
            echo "Configuração '$governor' já está aplicada. Nenhuma alteração necessária."
            return
        fi
    fi

    # Verifica o estado atual de cada CPU e aplica o novo governador apenas se necessário
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        local current_cpu_governor
        current_cpu_governor=$(<"$cpu")
        if [[ "$current_cpu_governor" != "$governor" ]]; then
            echo "$governor" | sudo tee "$cpu" > /dev/null
        fi
    done

    # Salva o novo estado no arquivo
    echo "$new_state" | sudo tee "$state_file" > /dev/null
    echo "Configuração '$governor' aplicada com sucesso."
}