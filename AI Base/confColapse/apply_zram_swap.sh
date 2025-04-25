apply_zram_swap() {
    local percent="$1"
    local mem_total
    mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local desired_swap_size
    desired_swap_size=$((mem_total * percent / 100))
    
    for zram_dev in /dev/zram*; do
        local current_swap_size
        current_swap_size=$(cat "/sys/block/$(basename "$zram_dev")/disksize" 2>/dev/null || echo 0)
        if [[ "$current_swap_size" -ne "$desired_swap_size" ]]; then
            echo "${desired_swap_size}K" | sudo tee "/sys/block/$(basename "$zram_dev")/disksize" > /dev/null
            sudo mkswap "$zram_dev"
            sudo swapon "$zram_dev"
            echo "✔️ Swap ZRAM configurado em $zram_dev (${percent}%)"
        else
            echo "⚙️ Swap ZRAM já configurado em $zram_dev (${percent}%)"
        fi
    done
}