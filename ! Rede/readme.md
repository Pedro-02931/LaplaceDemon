Aqui está o script para otimizar a rede, incluindo o ajuste das configurações de interface de rede (`iw`, `ethtool`, e outros parâmetros do kernel). Ele segue a mesma estrutura para garantir que os ajustes sejam feitos de maneira adaptativa, com logs e tratamento de erros.

### Script para Otimização de Rede

```bash
#!/bin/bash
#
# 🚀 rede-otimizador.sh – Otimizador adaptativo de rede (iw, ethtool, parâmetros do kernel)
# - Ajustes para melhorar a performance de rede via interface Wi-Fi (wlp2s0)
#

LOG_PATH="/var/log/rede-otimizador.log"
ERRORLOG=$(mktemp)

log()   { echo "[INFO]  $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_PATH"; }
warn()  { echo "[WARN]  $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_PATH"; }
error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_PATH" | tee -a "$ERRORLOG"; }

trap 'error "Linha $LINENO: comando falhou."' ERR
set -euo pipefail

[[ $EUID -ne 0 ]] && { error "Execute como root."; exit 1; }
log "Iniciando Otimizador de Rede..."

# --- Parâmetros de rede ajustáveis ---
declare -A REDE_POLITICAS=(
  ["20"]="1000 8192 16"
  ["50"]="2000 16384 8"
  ["80"]="4000 32767 4"
  ["100"]="8000 65535 2"
)

# --- Obtém a qualidade de sinal do Wi-Fi (em dBm) ---
get_wifi_signal_strength() {
  local strength
  strength=$(iw dev wlp2s0 station dump | awk '/signal/ {print $2}')
  echo "${strength:-0}"
}

# --- Encontra a política de rede com base na força do sinal ---
encontrar_politica_rede() {
  local sinal=$1 menor=100 poli=""
  for k in "${!REDE_POLITICAS[@]}"; do
    if (( sinal <= k )) && (( k < menor )); then
      menor=$k
      poli=${REDE_POLITICAS[$k]}
    fi
  done
  echo "$poli"
}

# --- Aplica as configurações de rede ---
aplicar_rede_policy() {
  local sinal=$(get_wifi_signal_strength)
  IFS=' ' read -r txq limit wmem <<< "$(encontrar_politica_rede "$sinal")"

  log "Sinal Wi-Fi: ${sinal} dBm. Política: txq_limit=$txq, wmem_max=$wmem"

  # Ajuste do txq_limit (transmissão de pacotes)
  iw dev wlp2s0 set txq_limit "$txq"

  # Ajuste do limite máximo do buffer de envio de rede
  echo "$wmem" > /proc/sys/net/core/wmem_max

  # Ajuste de latência de RX e TX para Wi-Fi
  ethtool -C wlp2s0 rx-usecs 8 tx-usecs 16
}

# Execução
aplicar_rede_policy || error "Rede tuning falhou"

# --- Sumário de erros ---
log "📋 Erros detectados durante execução:"
if [[ -s "$ERRORLOG" ]]; then
  sed 's/^/[❌]/' "$ERRORLOG"
else
  log "Nenhum erro encontrado."
fi

log "✅ Otimização de Rede concluída."
```

---

### Serviço Systemd `/etc/systemd/system/rede-otimizador.service`

```ini
[Unit]
Description=Otimizador adaptativo de Rede (Wi-Fi)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/rede-otimizador.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
```

### Timer Systemd `/etc/systemd/system/rede-otimizador.timer`

```ini
[Unit]
Description=Timer para Otimizar Rede periodicamente
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

1. Torne o script executável:

   ```bash
   chmod +x /usr/local/bin/rede-otimizador.sh
   ```

2. Atualize o Systemd e ative o serviço e o timer:

   ```bash
   systemctl daemon-reload
   systemctl enable --now rede-otimizador.service
   systemctl enable --now rede-otimizador.timer
   ```

---

### Explicação do Funcionamento:

- **Leitura da Força do Sinal Wi-Fi**: Utiliza o comando `iw dev wlp2s0 station dump` para obter a força do sinal em dBm.
- **Política Adaptativa**: Com base na força do sinal, são escolhidos diferentes níveis para o `txq_limit` (limite de fila de transmissão de pacotes), `wmem_max` (máximo de memória para buffer de transmissão) e configurações de latência de RX/TX.
- **Ajustes**:
  - **`iw dev wlp2s0 set txq_limit`**: Configura o limite da fila de transmissão de pacotes.
  - **`echo wmem_max`**: Ajusta o limite máximo de memória do buffer de transmissão para melhorar a performance.
  - **`ethtool -C`**: Ajusta a latência da interface Wi-Fi para um desempenho ideal de TX/RX.
  
Com isso, o script se adapta automaticamente ao sinal Wi-Fi e ajusta as configurações de rede para otimizar a performance com base no ambiente de rede e configurações de hardware.