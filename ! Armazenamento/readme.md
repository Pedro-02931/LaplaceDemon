```bash
#!/bin/bash
#
# 🚀 storage-otimizador.sh – Otimizador Adaptativo de Storage (Btrfs + XFS + HDParm)
# - SSD /dev/sda | Btrfs (/) + XFS (/home)
# - Ajustes dinâmicos de compressão, balanceamento e readahead
#

LOG_PATH="/var/log/storage-otimizador.log"
ERRORLOG=$(mktemp)

log()   { echo "[INFO]  $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_PATH"; }
warn()  { echo "[WARN]  $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_PATH"; }
error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_PATH" | tee -a "$ERRORLOG"; }

trap 'error "Linha $LINENO: comando falhou."' ERR
set -euo pipefail

[[ $EUID -ne 0 ]] && { error "Execute como root."; exit 1; }
log "Iniciando Storage Otimizador..."

# --- Obter % de uso de I/O do disco /dev/sda (iostat %util) ---
get_disk_util() {
  local util
  util=$(iostat -dx /dev/sda 1 2 | awk '/sda/ {util=$NF} END {print int(util)}')
  echo "${util:-0}"
}

# --- Tabela de políticas adaptativas: compress_level balance_thresh readahead_kB ---
declare -A STORAGE_POLITICAS=(
  ["20"]="3 60 512"
  ["50"]="7 75 1024"
  ["80"]="15 90 2048"
  ["100"]="19 100 4096"
)

# --- Encontra política mais próxima ---
encontrar_politica_storage() {
  local uso=$1 menor=100 poli=""
  for k in "${!STORAGE_POLITICAS[@]}"; do
    if (( uso <= k )) && (( k < menor )); then
      menor=$k
      poli=${STORAGE_POLITICAS[$k]}
    fi
  done
  echo "$poli"
}

# --- Aplica a política escolhida ---
aplicar_storage_policy() {
  local uso=$(get_disk_util)
  IFS=' ' read -r lvl bal rea <<< "$(encontrar_politica_storage "$uso")"

  log "I/O Util: ${uso}%. Política: compress=zstd:$lvl, balance=${bal}%, readahead=${rea}KB"

  # Btrfs: defrag + compressão; balance
  btrfs filesystem defragment -r -czstd:$lvl -f /
  btrfs balance start -dusage=$bal -musage=$bal /

  # XFS: fragmentação leve
  xfs_db -x /dev/sda3 -c frag

  # hdparm: write cache + read‑ahead
  hdparm -W1 /dev/sda
  hdparm -a$rea /dev/sda
}

# Execução
aplicar_storage_policy || error "Storage tuning falhou"

# --- Sumário de erros ---
log "📋 Erros detectados durante execução:"
if [[ -s "$ERRORLOG" ]]; then
  sed 's/^/[❌]/' "$ERRORLOG"
else
  log "Nenhum erro encontrado."
fi

log "✅ Storage Otimizador concluído."
```

---

#### Serviço Systemd `/etc/systemd/system/storage-otimizador.service`

```ini
[Unit]
Description=Otimizador adaptativo de Storage (Btrfs + XFS + hdparm)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/storage-otimizador.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
```

#### Timer Systemd `/etc/systemd/system/storage-otimizador.timer`

```ini
[Unit]
Description=Timer para Storage Otimizador
After=network.target

[Timer]
OnBootSec=2min
OnUnitActiveSec=15min
Persistent=true

[Install]
WantedBy=timers.target
```

---

### 🚀 Ativação

```bash
chmod +x /usr/local/bin/storage-otimizador.sh
systemctl daemon-reload
systemctl enable --now storage-otimizador.service
systemctl enable --now storage-otimizador.timer
```

**Como funciona, por trechos:**

1. **Leitura de I/O**: usa `iostat` para pegar `%util` de `/dev/sda`.  
2. **Política adaptativa**: escolhe compressão, balanceamento e readahead conforme carga.  
3. **Btrfs**: defrag recursivo + compressão ZSTD no nível escolhido, depois balanceamento parcial.  
4. **XFS**: checa fragmentação via `xfs_db`.  
5. **hdparm**: ativa write cache e ajusta read‑ahead dinamicamente.  
6. **Logs**: informa cada passo e coleta erros para revisão no final.