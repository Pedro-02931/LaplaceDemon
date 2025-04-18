#!/bin/bash
set -euo pipefail

declare -A CONFIG=(
  ["10"]="10 zstd $(nproc) 5 off"
  ["30"]="25 lz4 $(nproc) 15 off"
  ["50"]="40 zstd $(nproc) 20 off"
  ["65"]="50 lzo $(( $(nproc)*2 )) 25 on"
  ["80"]="70 lz4 $(( $(nproc)*3 )) 30 on"
  ["95"]="90 zstd $(( $(nproc)*4 )) 35 on"
)

while true; do
  mem_total=$(awk '/MemTotal/{print $2}' /proc/meminfo)
  mem_available=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
  uso_mem=$(( (mem_total - mem_available) * 100 / mem_total ))

  for lim in 10 30 50 65 80 95; do
    (( uso_mem <= lim )) && { chave="$lim"; break; }
  done

  read -r percent alg streams swappiness zswap <<< "${CONFIG[$chave]}"

  echo "[🌀 $(date +%T)] Uso: ${uso_mem}% | ZRAM: ${percent}% | Alg: ${alg} | Streams: ${streams} | Swap: ${swappiness} | ZSWAP: ${zswap}"
  
  sleep 15
done
