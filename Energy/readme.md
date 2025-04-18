```bash
#!/bin/bash
#
# 🚀 energia-otimizador.sh – Otimizador Adaptativo de Energia e Térmica
# - Gerencia TLP e Thermald segundo carga térmica e estado de energia (AC/Bateria)
#

LOG_PATH="/var/log/energia-otimizador.log"
ERRORLOG=$(mktemp)

log()   { echo "[INFO]  $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_PATH"; }
warn()  { echo "[WARN]  $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_PATH"; }
error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_PATH" | tee -a "$ERRORLOG"; }

trap 'error "Linha $LINENO: comando falhou."' ERR
set -euo pipefail

[[ $EUID -ne 0 ]] && { error "Execute como root."; exit 1; }
log "Iniciando Otimizador de Energia/Térmica..."

# 1) Habilita serviços se necessário
log "Habilitando thermald e tlp..."
{
  systemctl enable --now thermald
  systemctl enable --now tlp
} || error "Falha ao habilitar thermald/tlp"

# 2) Lê temperatura média da CPU (Core 0 e 1)
get_cpu_temp() {
  sensors -u coretemp-isa-0 | awk '/input/ {sum+=$2; count++} END {print int(sum/count)}'
}

# 3) Verifica se está em AC ou bateria
get_power_state() {
  # tenta interface sysfs, senão usa upower
  if [[ -f /sys/class/power_supply/AC/online ]]; then
    [[ $(cat /sys/class/power_supply/AC/online) -eq 1 ]] && echo "AC" || echo "BAT"
  else
    upower -i "$(upower -e | grep battery)" | awk '/state/ {print toupper($2)}'
  fi
}

# 4) Tabela adaptativa: temp_threshold => tlp_profile
declare -A ENERGY_POLICIAS=(
  ["50"]="balance_power"
  ["70"]="balance_performance"
  ["90"]="performance"
  ["100"]="performance"
)

find_energy_policy() {
  local temp=$1 best=100 prof=""
  for t in "${!ENERGY_POLICIAS[@]}"; do
    if (( temp <= t )) && (( t < best )); then
      best=$t
      prof=${ENERGY_POLICIAS[$t]}
    fi
  done
  echo "$prof"
}

# 5) Aplica política conforme temperatura e estado
apply_energy_policy() {
  local temp=$(get_cpu_temp)
  local power=$(get_power_state)
  local profile=$(find_energy_policy "$temp")

  log "CPU Temp: ${temp}°C | Power: $power | Aplicando TLP profile: $profile"

  if [[ "$power" == "AC" ]]; then
    tlp ac --CPU_ENERGY_PERF_POLICY_ON_AC="$profile" >/dev/null
  else
    tlp bat --CPU_ENERGY_PERF_POLICY_ON_BAT="$profile" >/dev/null
  fi
}

# Execução
apply_energy_policy || error "Falha na aplicação de perfil de energia"

# 6) Sumário de erros
log "📋 Erros detectados:"
if [[ -s "$ERRORLOG" ]]; then
  sed 's/^/[❌]/' "$ERRORLOG"
else
  log "Nenhum erro encontrado."
fi

log "✅ Energia/Térmica otimizado com sucesso!"
```

---

#### Serviço Systemd `/etc/systemd/system/energia-otimizador.service`

```ini
[Unit]
Description=Otimizador adaptativo de Energia e Térmica
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/energia-otimizador.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
```

#### Timer Systemd `/etc/systemd/system/energia-otimizador.timer`

```ini
[Unit]
Description=Timer para Otimizador de Energia/Térmica
After=network.target

[Timer]
OnBootSec=1min
OnUnitActiveSec=10min
Persistent=true

[Install]
WantedBy=timers.target
```

---

### 🚀 Ativação

```bash
chmod +x /usr/local/bin/energia-otimizador.sh
systemctl daemon-reload
systemctl enable --now energia-otimizador.service
systemctl enable --now energia-otimizador.timer
```

**Como funciona:**
1. **Habilita** `thermald` e `tlp` para controle de limites térmicos e políticas de energia.  
2. **Lê** a temperatura média da CPU via `sensors`.  
3. **Determina** se o sistema está em **AC** ou **bateria**.  
4. **Consulta** uma **tabela adaptativa** de limiares de temperatura para escolher o perfil TLP adequado (`balance_power`, `balance_performance`, `performance`).  
5. **Aplica** o perfil via `tlp ac --...` ou `tlp bat --...`.  
6. **Registra** todo o processo em log, e no final extrai **apenas** as mensagens de erro, se houver.