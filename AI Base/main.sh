#!/bin/bash
set -euo pipefail
trap 'error "Erro na linha $LINENO: Comando falhou."' ERR

# Variaveis, arquivos e logs
readonly LOG_PATH="/var/log/bayesengineLOG.log"
readonly VERIFICATION_LOG="/var/log/bayesengineID.log"
readonly HISTORY_FILE="/var/opt/CPU_USAGE.optstatus"
readonly STATUS_FILE="/var/opt/energy.optStatus"
readonly SCRIPT_PATH="/usr/local/bin/bayesengine.sh"
readonly SERVICE_PATH="/etc/systemd/system/bayesengine.service"
readonly TIMER_PATH="/etc/systemd/system/bayesengine.timer"
readonly MAX_HISTORY=15
readonly EMA_ALPHA=0.3
readonly CRITICAL_TEMP_THRESHOLD=85000
readonly HIGH_LOAD_THRESHOLD=75
readonly LOW_LOAD_THRESHOLD=20
readonly MIN_SLEEP_INTERVAL=15
readonly MAX_SLEEP_INTERVAL=120


<< EOF
que porra é:
- CRITICAL_TEMP_THRESHOLD e por que é 85000
- EMA_ALPHA e por que é 0.3
- MAX_HISTORY e por que é 15
- HIGH_LOAD_THRESHOLD e por que é 75
- LOW_LOAD_THRESHOLD e por que é 20
- MIN_SLEEP_INTERVAL e por que é 15
- MAX_SLEEP_INTERVAL e por que é 120
EOF


declare -A SAFE_LIMITS=(
    [TDP]=50
    [VRAM_CLOCK]=1500
    [BOOST_CLOCK]=1800
    [CPU_TEMP]=95000
)
# Aqui pedi para a IA adaptar para o UHD 620, expliwur o wur significa cada um desses valores e a nomenclatura tecnica e acronimos e funcionamento a nivel lógico e eletrônico
# Que porra quer dizer ´declare -A´

declare -A EXECUCOES
declare CURRENT_POLICY_KEY=""
declare MODIFIED=0
declare LAST_LOG_MSG=""

# Carregar arquivos externos
source /bayesEngine/funcoes.sh
source /bayesEngine/variaveis.sh
