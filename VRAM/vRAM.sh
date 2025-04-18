#!/bin/bash
set -euo pipefail

echo "[*] Instalando auto-configuração de ZRAM/Zswap..."

# Caminhos
SCRIPT_PATH="/usr/local/bin/auto-zram.sh"
SERVICE_PATH="/etc/systemd/system/auto-zram.service"
TIMER_PATH="/etc/systemd/system/auto-zram.timer"

# 1. Criar o script principal
cat <<'EOF' | sudo tee "$SCRIPT_PATH" > /dev/null
#!/bin/bash
set -euo pipefail


declare -A CONFIG=(
  ["05"]="5 zstd 1 1 off"
  ["10"]="10 zstd $(nproc) 5 off"
  ["30"]="25 lz4 $(nproc) 15 off"
  ["50"]="40 zstd $(nproc) 20 off"
  ["65"]="50 lzo $(( $(nproc)*2 )) 25 on"
  ["80"]="70 lz4 $(( $(nproc)*3 )) 30 on"
  ["95"]="90 zstd $(( $(nproc)*4 )) 35 on"
)

GRUB_FILE="/etc/default/grub"
SYSCTL_CONF="/etc/sysctl.d/99-zram.conf"

collect_usage() {
  mem_total=$(awk '/MemTotal/{print $2}' /proc/meminfo)
  mem_available=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
  uso_mem=$(( (mem_total - mem_available) * 100 / mem_total ))
}

select_policy() {
  for lim in 05 10 30 50 65 80 95; do
    (( uso_mem <= lim )) && { chave="$lim"; break; }
  done
  read -r percent alg streams swappiness zswap <<< "${CONFIG[$chave]}"
}


apply_zramctl() {
  sudo swapoff -a || true
  sudo modprobe zram
  for dev in /dev/zram*; do
    [[ -e "$dev" ]] && sudo swapoff "$dev" && echo 1 | sudo tee "/sys/block/$(basename $dev)/reset" >/dev/null
  done

  for i in $(seq 0 $((streams - 1))); do
    echo $i | sudo tee /sys/class/zram-control/hot_add >/dev/null
    echo "$alg" | sudo tee /sys/block/zram$i/comp_algorithm >/dev/null
    echo "$((mem_total / 1024 * percent / 100 / streams))M" | sudo tee /sys/block/zram$i/disksize >/dev/null
    sudo mkswap /dev/zram$i
    sudo swapon /dev/zram$i
  done
}

apply_sysctl() {
  min_free_kb=$(( mem_total / 100 ))
  sudo tee "$SYSCTL_CONF" >/dev/null <<EOF2
vm.swappiness=$swappiness
vm.vfs_cache_pressure=30
vm.dirty_background_ratio=5
vm.dirty_ratio=10
vm.min_free_kbytes=$min_free_kb
EOF2
  sudo sysctl -p "$SYSCTL_CONF" >/dev/null
}

# >> ADIÇÃO DO CONCEITO DE COLAPSO (sem mexer no resto)
needs_change() {
  current_swap=$(sysctl -n vm.swappiness 2>/dev/null || echo -1)
  current_streams=$(ls /dev/zram* 2>/dev/null | wc -l)
  current_alg=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null | awk '{print $1}')

  [[ "$current_swap" -ne "$swappiness" ]] && return 0
  [[ "$current_streams" -ne "$streams" ]] && return 0
  [[ "$current_alg" != "$alg" ]] && return 0
  return 1
}

main() {
  collect_usage
  select_policy

  if needs_change; then
    apply_zramctl
    apply_sysctl
  fi
}

main
EOF

# Permissões
sudo chmod +x "$SCRIPT_PATH"
echo "[+] Script criado em $SCRIPT_PATH"

# 2. Criar o serviço
cat <<EOF | sudo tee "$SERVICE_PATH" > /dev/null
[Unit]
Description=Ajuste automático de ZRAM/Zswap
After=multi-user.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
EOF

echo "[+] Serviço criado em $SERVICE_PATH"

# 3. Criar o timer
cat <<EOF | sudo tee "$TIMER_PATH" > /dev/null
[Unit]
Description=Timer para $SERVICE_PATH

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

echo "[+] Timer criado em $TIMER_PATH"

# 4. Ativar tudo
echo "[*] Ativando serviço e timer..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now auto-zram.timer

echo "[✅] Auto-ZRAM/Zswap configurado com sucesso!"
systemctl list-timers | grep auto-zram
