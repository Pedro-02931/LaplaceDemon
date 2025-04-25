### Tentei remover o EPB por complexidade desnecessaria
# Função para arredondar para cima
ceil() {
    echo $(( ($1 + $2 - 1) / $2 ))
}

declare -A HOLISTIC_POLICIES=(
    # Formato: "CPU Gov | Power Limit (%TDP) | TDP Limit (%TDP) | GPU Clock (%GPU_MAX) | | Algoritmo ZRAM | Streams | Swappiness"
    ["000"]="powersave   $((MAX_TDP * 20 / 100)) $((MAX_TDP * 15 / 100)) $((MAX_GPU_CLOCK * 30 / 100)) zstd $((CORES_TOTAL * 25 / 100)) 10"
    ["010"]="powersave   $((MAX_TDP * 25 / 100)) $((MAX_TDP * 18 / 100)) $((MAX_GPU_CLOCK * 35 / 100)) zstd $((CORES_TOTAL * 30 / 100)) 15"
    ["020"]="powersave   $((MAX_TDP * 30 / 100)) $((MAX_TDP * 20 / 100)) $((MAX_GPU_CLOCK * 40 / 100)) lz4  $((CORES_TOTAL * 40 / 100)) 20"
    ["030"]="powersave   $((MAX_TDP * 35 / 100)) $((MAX_TDP * 22 / 100)) $((MAX_GPU_CLOCK * 45 / 100)) lz4  $((CORES_TOTAL * 50 / 100)) 25"
    ["040"]="ondemand    $((MAX_TDP * 40 / 100)) $((MAX_TDP * 25 / 100)) $((MAX_GPU_CLOCK * 50 / 100)) lzo  $((CORES_TOTAL * 60 / 100)) 30"
    ["050"]="conservative $((MAX_TDP * 50 / 100)) $((MAX_TDP * 30 / 100)) $((MAX_GPU_CLOCK * 60 / 100)) lz4  $((CORES_TOTAL * 70 / 100)) 35"
    ["060"]="conservative $((MAX_TDP * 60 / 100)) $((MAX_TDP * 35 / 100)) $((MAX_GPU_CLOCK * 70 / 100)) lzo  $((CORES_TOTAL * 80 / 100)) 40"
    ["070"]="performance $((MAX_TDP * 70 / 100)) $((MAX_TDP * 40 / 100)) $((MAX_GPU_CLOCK * 80 / 100)) zstd $((CORES_TOTAL * 90 / 100)) 50"
    ["080"]="performance $((MAX_TDP * 90 / 100)) $((MAX_TDP * 50 / 100)) $((MAX_GPU_CLOCK * 90 / 100)) lz4  $((CORES_TOTAL)) 55"
    ["090"]="performance $((MAX_TDP * 95 / 100)) $((MAX_TDP * 55 / 100)) $((MAX_GPU_CLOCK * 95 / 100)) lz4  $((CORES_TOTAL)) 60"
    ["100"]="performance $((MAX_TDP))           $((MAX_TDP))           $((MAX_GPU_CLOCK))           zstd $((CORES_TOTAL)) 65"
)

<< EOF
Falta criar o que implementa a flag critical booleana
Explique que porra são essas informações, funcionamento a nivel logico e eletrônico e seus acronimos.
- CPU Gov
- GPU Perf
- EPB
- Power Limit (%TDP)
- TDP Limit (%TDP)
- GPU Clock (%GPU_MAX)
- VRAM Clock
- Algoritmo ZRAM
- Streams
- Swappiness
- lz4
- lzo
- zstd
EOF