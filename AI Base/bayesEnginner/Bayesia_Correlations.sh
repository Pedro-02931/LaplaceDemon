#!/bin/bash
declare -A HOLISTIC_POLICIES=(
    # Formato: "CPU Gov | Power Limit (%TDP) | TDP Limit (%TDP) | | Algoritmo ZRAM | Streams | Swappiness"
    ["000"]="ondemand    $((MAX_TDP * 20 / 100)) $((MAX_TDP * 15 / 100)) zstd $((CORES_TOTAL * 25 / 100)) 10"
    ["010"]="ondemand    $((MAX_TDP * 25 / 100)) $((MAX_TDP * 18 / 100)) zstd $((CORES_TOTAL * 30 / 100)) 15"
    ["020"]="ondemand    $((MAX_TDP * 30 / 100)) $((MAX_TDP * 20 / 100)) lz4  $((CORES_TOTAL * 40 / 100)) 20"
    ["030"]="ondemand    $((MAX_TDP * 35 / 100)) $((MAX_TDP * 22 / 100)) lz4  $((CORES_TOTAL * 50 / 100)) 25"
    ["040"]="ondemand    $((MAX_TDP * 40 / 100)) $((MAX_TDP * 25 / 100)) lzo  $((CORES_TOTAL * 60 / 100)) 30"
    ["050"]="userspace   $((MAX_TDP * 50 / 100)) $((MAX_TDP * 30 / 100)) lz4  $((CORES_TOTAL * 70 / 100)) 35"
    ["060"]="userspace   $((MAX_TDP * 60 / 100)) $((MAX_TDP * 35 / 100)) lzo  $((CORES_TOTAL * 80 / 100)) 40"
    ["070"]="performance $((MAX_TDP * 70 / 100)) $((MAX_TDP * 40 / 100)) zstd $((CORES_TOTAL * 90 / 100)) 50"
    ["080"]="performance $((MAX_TDP * 90 / 100)) $((MAX_TDP * 50 / 100)) lz4  $((CORES_TOTAL)) 55"
    ["090"]="performance $((MAX_TDP * 95 / 100)) $((MAX_TDP * 55 / 100)) lz4  $((CORES_TOTAL)) 60"
    ["100"]="performance $((MAX_TDP))           $((MAX_TDP))           zstd $((CORES_TOTAL)) 65"
)
