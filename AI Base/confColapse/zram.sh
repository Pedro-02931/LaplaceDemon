apply_zramctl() {
    local alg="$1"          # Algoritmo de compressão (ex: zstd, lz4, lzo)
    local streams="$2"      # Número de streams (ex: 4)
    local percent="$3"      # Percentual de memória total a ser usado (ex: 50)
    local state_file="/var/optEnergy/zram_config"  # Arquivo para armazenar o estado atual
    local current_state
    local new_state

    # Calcula a memória total do sistema em KB
    local mem_total
    mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')

    # Gera o estado atual baseado nos argumentos
    new_state="${alg}_${streams}_${percent}"

    # Verifica se o estado atual já foi salvo
    if [[ -f "$state_file" ]]; then
        current_state=$(<"$state_file")
        if [[ "$current_state" == "$new_state" ]]; then
            echo "Configuração do ZRAM já está aplicada. Nenhuma alteração necessária."
            return
        fi
    fi

    echo "Aplicando configuração do ZRAM: Algoritmo=$alg, Streams=$streams, Percentual=$percent%..."

    # Desativa swaps existentes e reseta dispositivos ZRAM apenas se necessário
    local current_alg current_streams current_percent
    current_alg=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null || echo "none")
    current_streams=$(ls /dev/zram* 2>/dev/null | wc -l)
    current_percent=$(awk -v mem_total="$mem_total" -v disksize="$(cat /sys/block/zram0/disksize 2>/dev/null || echo 0)" \
        'BEGIN { printf "%.0f", (disksize * 100 * '"$streams"') / (mem_total * 1024) }')

    if [[ "$current_alg" == "$alg" && "$current_streams" -eq "$streams" && "$current_percent" -eq "$percent" ]]; then
        echo "Configuração do ZRAM já está aplicada. Nenhuma alteração necessária."
        return
    fi

    # Desativa swaps e reseta dispositivos ZRAM
    sudo swapoff -a || true
    sudo modprobe zram
    for dev in /dev/zram*; do
        if [[ -e "$dev" ]]; then
            sudo swapoff "$dev" || true
            echo 1 | sudo tee "/sys/block/$(basename "$dev")/reset" >/dev/null
        fi
    done

    # Configura os dispositivos ZRAM
    for i in $(seq 0 $((streams - 1))); do
        echo "$i" | sudo tee /sys/class/zram-control/hot_add >/dev/null
        echo "$alg" | sudo tee /sys/block/zram$i/comp_algorithm >/dev/null
        echo "$((mem_total / 1024 * percent / 100 / streams))M" | sudo tee /sys/block/zram$i/disksize >/dev/null
        sudo mkswap /dev/zram$i
        sudo swapon /dev/zram$i
    done

    # Salva o novo estado no arquivo
    echo "$new_state" | sudo tee "$state_file" >/dev/null
    echo "Configuração do ZRAM aplicada com sucesso."
}