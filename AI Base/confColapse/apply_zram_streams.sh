apply_zram_streams() {
    local streams="$1"  # Número de streams
    local current_streams
    current_streams=$(ls /dev/zram* 2>/dev/null | wc -l)
    if [[ "$current_streams" -ne "$streams" ]]; then
        # Redefine os dispositivos ZRAM
        sudo swapoff -a || true
        sudo modprobe zram
        for dev in /dev/zram*; do
            if [[ -e "$dev" ]]; then
                sudo swapoff "$dev" || true
                echo 1 | sudo tee "/sys/block/$(basename "$dev")/reset" > /dev/null
            fi
        done
        
        # Configura os dispositivos ZRAM
        for i in $(seq 0 $((streams - 1))); do
            echo "$i" | sudo tee /sys/class/zram-control/hot_add > /dev/null
        done
        
        echo "✔️ Número de streams do ZRAM configurado para $streams"
    else
        echo "⚙️ Número de streams do ZRAM já está configurado como $streams"
    fi
}