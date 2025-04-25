apply_zram_algorithm() {
    local alg="$1" # Algoritmo de compressão (ex: zstd, lz4, lzo)

    for zram in /sys/block/zram*/comp_algorithm; do
        local current_alg
        current_alg=$(cat "$zram" 2>/dev/null || echo "none")
        if [[ "$current_alg" != "$alg" ]]; then
            echo "$alg" | sudo tee "$zram" > /dev/null
            echo "✔️ Algoritmo de compressão do ZRAM atualizado para $alg em $(basename "$(dirname "$zram")")"
        else
            echo "⚙️ Algoritmo de compressão do ZRAM já está configurado como $alg em $(basename "$(dirname "$zram")")"
        fi
    done
}



