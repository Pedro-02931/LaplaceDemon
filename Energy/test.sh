#!/bin/bash
#
# 🔥 stress-test-energia.sh - Coleta dados de desempenho/térmicos durante teste
#

LOG_DIR="/var/log/energy-stress-test"
mkdir -p "$LOG_DIR"

# Configurações do teste
DURATION=300      # 5 minutos de teste
STRESS_LEVEL=8    # Número de workers de estresse
INTERVAL=5        # Intervalo de coleta de dados em segundos

# Nome do arquivo de log com timestamp
LOG_FILE="$LOG_DIR/stress-test-$(date +%Y%m%d-%H%M%S).log"

# Verifica dependências
check_dependencies() {
    local missing=()
    command -v stress-ng >/dev/null || missing+=("stress-ng")
    command -v sensors >/dev/null || missing+=("lm-sensors")
    command -v tlp >/dev/null || missing+=("tlp")
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Erro: Dependências faltando: ${missing[*]}"
        echo "Instale com: sudo apt install stress-ng lm-sensors tlp"
        exit 1
    fi
}

# Coleta métricas do sistema
collect_metrics() {
    local phase=$1
    echo "=== $(date +'%Y-%m-%d %H:%M:%S') [$phase] ===" >> "$LOG_FILE"
    
    # Dados TLP
    echo "[TLP Configuration]" >> "$LOG_FILE"
    tlp-stat -c >> "$LOG_FILE"
    
    # Dados térmicos
    echo "[Thermal Data]" >> "$LOG_FILE"
    sensors -u >> "$LOG_FILE"
    
    # Dados de energia
    echo "[Power Data]" >> "$LOG_FILE"
    upower -i $(upower -e | grep BAT) >> "$LOG_FILE"
    
    # Uso CPU
    echo "[CPU Usage]" >> "$LOG_FILE"
    mpstat -P ALL 1 1 >> "$LOG_FILE"
    
    # Limite entre coleta
    echo -e "\n\n" >> "$LOG_FILE"
}

main() {
    check_dependencies
    echo "Iniciando teste de estresse. Logs em: $LOG_FILE"
    
    # Fase 1: Coleta baseline
    echo "Coletando baseline por 60 segundos..."
    collect_metrics "BASELINE"
    sleep 60
    
    # Fase 2: Teste de estresse
    echo "Iniciando estresse por $DURATION segundos..."
    stress-ng --cpu $STRESS_LEVEL --timeout $DURATION &
    STRESS_PID=$!
    
    # Coleta durante estresse
    while kill -0 $STRESS_PID 2>/dev/null; do
        collect_metrics "STRESS"
        sleep $INTERVAL
    done
    
    # Fase 3: Cooldown
    echo "Monitorando cooldown por 120 segundos..."
    for i in {1..24}; do
        collect_metrics "COOLDOWN"
        sleep 5
    done
    
    echo "Teste completo! Analise os logs em: $LOG_FILE"
}

# Execução principal com tratamento de interrupção
trap 'echo "Interrompendo teste..."; kill -TERM $STRESS_PID 2>/dev/null; exit' SIGINT SIGTERM
main