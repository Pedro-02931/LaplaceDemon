declare -A HOLISTIC_POLICIES=(
    # --- BATERIA (power_source=0) ---
    # Formato: "CPU Gov | GPU Perf | EPB | Power Limit (%TDP) | TDP Limit (%TDP) | GPU Clock (%GPU_MAX) | VRAM Clock | Algoritmo ZRAM | Streams | Swappiness"
    ["00000"]="powersave   battery     $EPB_POWERSAVE    $((MAX_TDP * 20 / 100))     $((MAX_TDP * 15 / 100))     $((MAX_GPU_CLOCK * 30 / 100))     300     zstd    1    10"
    ["00500"]="powersave   battery     $EPB_POWERSAVE    $((MAX_TDP * 25 / 100))     $((MAX_TDP * 18 / 100))     $((MAX_GPU_CLOCK * 35 / 100))     350     zstd    1    15"
    ["01000"]="powersave   battery     $EPB_POWERSAVE    $((MAX_TDP * 30 / 100))     $((MAX_TDP * 20 / 100))     $((MAX_GPU_CLOCK * 40 / 100))     400     lz4     2    20"
    ["02000"]="powersave   balanced    $EPB_BALANCED     $((MAX_TDP * 35 / 100))     $((MAX_TDP * 22 / 100))     $((MAX_GPU_CLOCK * 45 / 100))     450     lz4     2    25"
    ["03000"]="ondemand    balanced    $EPB_BALANCED     $((MAX_TDP * 40 / 100))     $((MAX_TDP * 25 / 100))     $((MAX_GPU_CLOCK * 50 / 100))     500     lzo     3    30"
    ["04000"]="ondemand    balanced    $EPB_BALANCED     $((MAX_TDP * 45 / 100))     $((MAX_TDP * 28 / 100))     $((MAX_GPU_CLOCK * 55 / 100))     550     zstd    3    35"
    ["05000"]="conservative balanced   $EPB_BALANCED     $((MAX_TDP * 50 / 100))     $((MAX_TDP * 30 / 100))     $((MAX_GPU_CLOCK * 60 / 100))     600     lz4     4    40"
    ["06000"]="conservative balanced   $EPB_BALANCED     $((MAX_TDP * 55 / 100))     $((MAX_TDP * 32 / 100))     $((MAX_GPU_CLOCK * 65 / 100))     650     lzo     4    45"
    ["07000"]="performance performance $EPB_PERFORMANCE  $((MAX_TDP * 60 / 100))     $((MAX_TDP * 35 / 100))     $((MAX_GPU_CLOCK * 70 / 100))     700     zstd    5    50"
    ["08000"]="performance performance $EPB_PERFORMANCE  $((MAX_TDP * 65 / 100))     $((MAX_TDP * 38 / 100))     $((MAX_GPU_CLOCK * 75 / 100))     750     lz4     5    55"
    ["09000"]="performance performance $EPB_PERFORMANCE  $((MAX_TDP * 70 / 100))     $((MAX_TDP * 40 / 100))     $((MAX_GPU_CLOCK * 80 / 100))     800     zstd    6    60"
    ["10000"]="performance performance $EPB_PERFORMANCE  $((MAX_TDP * 80 / 100))     $((MAX_TDP * 45 / 100))     $((MAX_GPU_CLOCK * 90 / 100))     900     zstd    6    65"

    # --- TOMADA (power_source=1) ---
    ["00001"]="performance performance $EPB_PERFORMANCE  $((MAX_TDP * 100 / 100))    $((MAX_TDP * 70 / 100))     $((MAX_GPU_CLOCK * 100 / 100))    900     zstd    2    5"
    ["01001"]="performance performance $EPB_PERFORMANCE  $((MAX_TDP * 100 / 100))    $((MAX_TDP * 80 / 100))     $((MAX_GPU_CLOCK * 100 / 100))    1000    lz4     3    10"
    ["02001"]="performance performance $EPB_PERFORMANCE  $((MAX_TDP * 100 / 100))    $((MAX_TDP * 90 / 100))     $((MAX_GPU_CLOCK * 100 / 100))    1100    lz4     3    15"
    ["03001"]="ondemand    performance $EPB_PERFORMANCE  $((MAX_TDP * 100 / 100))    $((MAX_TDP * 100 / 100))    $((MAX_GPU_CLOCK * 100 / 100))    1200    lzo     4    20"
)