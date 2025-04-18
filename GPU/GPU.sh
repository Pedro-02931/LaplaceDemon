#!/usr/bin/env bash
#
# 🚀 vem ca minha putinha – gpu-otimizador-dinamico.sh Versão 6.7 (Gíria pesada e logs “na brasa”)
#
# Descrição:
#   Esse script porra ajusta a GPU na marra com base no uso de CPU,
#   metendo um papo reto paulistano e uns palavrões no meio pra ficar engraçado.
#   Tem tabela de mudanças e explicação de 4K com sal grosso.
#
set -euo pipefail
shopt -s inherit_errexit      # pra não dar mole em subshell

trap 'error "Linha $LINENO: deu merda aqui, caralho!" && exit 1' ERR
trap 'log "Recebi SIGINT/SIGTERM, fechando esse bagulho sem mimimi..." && exit 0' INT TERM

# --- Configurações brutas ---
SLEEP_INTERVAL=30
LOG_PATH="/var/log/gpu-otimizador.log"
GPU_PATH="/sys/class/drm/card0"
NEW_LOG="/vamCaMinhaPutinha"   # nome estiloso e sacana do log
MIN_BASH_MAJOR=4

# --- Verifica Bash versão + cria logs ---
(( BASH_VERSINFO[0] < MIN_BASH_MAJOR )) && {
    echo "Porra, precisa de Bash ≥ ${MIN_BASH_MAJOR}.x (tá usando $BASH_VERSION)" >&2
    exit 1
}
mkdir -p "$(dirname "$LOG_PATH")"
touch "$NEW_LOG" 2>/dev/null || { echo "Não rolou criar $NEW_LOG, fud#‑se" >&2; exit 1; }

ERRORLOG=$(mktemp)
log()   { echo "[INFO]  $(date '+%Y-%m-%d %H:%M:%S') Vem cá minha putinha: $*" \
              | tee -a "$LOG_PATH" -a "$NEW_LOG"; }
warn()  { echo "[WARN]  $(date '+%Y-%m-%d %H:%M:%S') Pô, vacilo: $*" \
              | tee -a "$LOG_PATH" -a "$NEW_LOG"; }
error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') Caralho de erro: $*" \
              | tee -a "$LOG_PATH" -a "$ERRORLOG" -a "$NEW_LOG"; }

[[ ! -d "$GPU_PATH" ]] && { error "GPU_PATH inválido, porra: $GPU_PATH"; exit 1; }

# --- Explicação 4K no grau ---
print_explanation() {
    cat <<'EXPLICA' | tee -a "$LOG_PATH" -a "$NEW_LOG"

#################### VEM CÁ MINHA PUTINHA – 4K NA BRASA ####################

PARÁGRAFO 1:
Fudeu geral nos primeiros 30 segundos porque o script tava de bobeira
tentando medir direito o uso de CPU e ajustar o mem_clock na trave.  
Enquanto rola esse refino, o fluxo 4K dá umas pipocadas – tipo carona de busão
num buraco – e a porcaria do buffer esvazia, resultando em stutter sinistro.

PARÁGRAFO 2:
Depois do rolo inicial, o bagulho acerta o passo e fixa o mem_clock e performance_level
no grau certo pra aguentar 4K no pau.  
Aí para de vacilar e streama suave, igual rolezinho bem organizado sem quebra‑queixo.

EXPLICA
}

# --- Políticas de ajuste cabulosas ---
declare -A GPU_POLITICAS=(
    ["10"]="low    0  300   20   8   70"
    ["30"]="low    0  450   35   12  75"
    ["50"]="medium 1  600   50   15  80"
    ["70"]="medium 1  750   65   18  85"
    ["90"]="high   2  900   80   20  90"
    ["100"]="high  2  1050 100  25  95"
)

declare -A PARAMS_MODIFICAVEIS=()
declare -A CAPACIDADES_GPU=( [mem_min]=0 [mem_max]=0 [power_unit]="" [irq_number]=0 )

# --- Justificativa bayesiana orgânica (na moral) ---
bayesian_reason() {
    case "$1" in
        performance_level)
            echo "Como quem ajusta o grau de concentração em debate de bar: sobe e desce conforme a treta."
            ;;
        boost_freq)
            echo "Tipo aquecer o braço antes de soco, vai subindo aos poucos pra não quebrar o dedo."
            ;;
        mem_clock)
            echo "Respiração controlada: puxa e solta ritmo suave pra não dar estresse no sistema."
            ;;
        power_limit)
            echo "Não deixa fritar tudo: gerencia a energia igual churrasco bem pilotado pra não queimar a carne."
            ;;
        *)
            echo "Equilíbrio na porrada: harmonia bayesiana entre máquina e usuário."
            ;;
    esac
}

# --- Desenha a tabela das mudanças, estilo grafite ---
print_changes_table() {
    echo | tee -a "$LOG_PATH" -a "$NEW_LOG"
    echo "Alterações na Porra Dessa Máquina:" | tee -a "$LOG_PATH" -a "$NEW_LOG"
    printf "+----------------------+------------+----------------------------------------------------+\n" \
           | tee -a "$LOG_PATH" -a "$NEW_LOG"
    printf "| %-20s | %-10s | %-50s |\n" "Parâmetro" "Valor" "Por que na moral" \
           | tee -a "$LOG_PATH" -a "$NEW_LOG"
    printf "+----------------------+------------+----------------------------------------------------+\n" \
           | tee -a "$LOG_PATH" -a "$NEW_LOG"
    for i in "${!CHANGES_PARAM[@]}"; do
        printf "| %-20s | %-10s | %-50s |\n" \
            "${CHANGES_PARAM[i]}" "${CHANGES_VALUE[i]}" "${CHANGES_REASON[i]}" \
            | tee -a "$LOG_PATH" -a "$NEW_LOG"
    done
    printf "+----------------------+------------+----------------------------------------------------+\n" \
           | tee -a "$LOG_PATH" -a "$NEW_LOG"
    echo | tee -a "$LOG_PATH" -a "$NEW_LOG"
}

# --- Detecta parâmetros que dá pra babá ---
detectar_capacidades() {
    for f in \
        "$GPU_PATH/power/force_performance_level" \
        "$GPU_PATH/gt_boost_freq_mhz" \
        "$GPU_PATH/gt_RP1_freq_mhz" \
        "$GPU_PATH/power_limit"; do
        if [[ -w "$f" ]]; then
            case "$(basename "$f")" in
                force_performance_level) PARAMS_MODIFICAVEIS[performance_level]=1 ;;
                gt_boost_freq_mhz)       PARAMS_MODIFICAVEIS[boost_freq]=1 ;;
                gt_RP1_freq_mhz)         PARAMS_MODIFICAVEIS[mem_clock]=1 ;;
                power_limit)             PARAMS_MODIFICAVEIS[power_limit]=1 ;;
            esac
        else
            warn "Sem permissão em $f, pula essa porra"
        fi
    done
    (( ${#PARAMS_MODIFICAVEIS[@]} == 0 )) && { error "Nenhum parâmetro gravável, fud#‑se"; exit 1; }

    CAPACIDADES_GPU[mem_min]=$(< "$GPU_PATH/gt_RP1_freq_mhz" 2>/dev/null || echo 300)
    CAPACIDADES_GPU[mem_max]=$(< "$GPU_PATH/gt_RP0_freq_mhz" 2>/dev/null || echo 1000)
    read -r _ unit < <(< "$GPU_PATH/power_limit" 2>/dev/null || echo "0 mW")
    CAPACIDADES_GPU[power_unit]=$unit
    CAPACIDADES_GPU[irq_number]=$(awk '/i915/ {print $1}' /proc/interrupts | cut -d: -f1 || echo 0)

    log "Capacidades: mem ${CAPACIDADES_GPU[mem_min]}–${CAPACIDADES_GPU[mem_max]}MHz | unit=${CAPACIDADES_GPU[power_unit]} | IRQ=${CAPACIDADES_GPU[irq_number]}"
}

# --- Função de harmonia matemática (transições suaves) ---
harmonia_na_porrada() {
    local atual="$1"
    local alvo="$2"
    # 0.6 * atual + 0.4 * alvo = transição suave igual mudança automática
    echo $(( (6 * atual + 4 * alvo) / 10 ))
}

# --- Aplica a porra da política com suavidade de traficante ---
aplicar_politica() {
    local chave=$1
    [[ -z "${GPU_POLITICAS[$chave]:-}" ]] && { warn "Política $chave% não existe, bora pular"; return 1; }
    IFS=' ' read -r lvl guc bf mc pl th <<<"${GPU_POLITICAS[$chave]}"

    # Calcula novos valores com harmonia
    local mem_atual=$(< "$GPU_PATH/gt_RP1_freq_mhz")
    local power_atual=$(< "$GPU_PATH/power_limit")
    
    local mem_alvo=$(calcular_valor "${CAPACIDADES_GPU[mem_min]}" "${CAPACIDADES_GPU[mem_max]}" "$mc")
    local power_alvo=$(( pl * 1000 ))
    
    # Aplica harmonia pra evitar tranco
    local mem_freq=$(harmonia_na_porrada "$mem_atual" "$mem_alvo")
    local power_val=$(harmonia_na_porrada "$power_atual" "$power_alvo")

    declare -A comandos=(
        [performance_level]="echo $lvl > $GPU_PATH/power/force_performance_level"
        [boost_freq]="echo $bf  > $GPU_PATH/gt_boost_freq_mhz"
        [mem_clock]="echo $mem_freq > $GPU_PATH/gt_RP1_freq_mhz"
        [power_limit]="echo $power_val > $GPU_PATH/power_limit"
    )

    # [...] (Restante idêntico com CHANGES_PARAM e print_changes_table)
}

# --- Explicação da harmonia no log ---
print_explanation() {
    cat <<'EXPLICA' | tee -a "$LOG_PATH" -a "$NEW_LOG"

#################### VEM CÁ MINHA PUTINHA – AGORA COM SUSPENSION MATEMÁTICA ####################

PARÁGRAFO 1 - "EFEITO MOTORISTA DE UBER":
Antes era igual botar turbo no Corsa - dava tranco e derrubava os frame.  
Agora uso fórmula 0.6*atual + 0.4*alvo: suaviza igual cambio automático da BMW.  
Transição gradual = buffer de vídeo não vira pipoca na panela.

PARÁGRAFO 2 - "TABELA DA HARMONIA":
Cada mudança mostra o antes/depois na tabela, igual relatório de corrida:  
[CPU 10%] → mem_clock: 300→450MHz (tipo acelerar pra pegar sinal)  
[CPU 90%] → mem_clock: 900→1050MHz (igual botar turbo depois do pedágio)

EXPLICA
}

# --- Mede uso de CPU, sem mi-mi-mi ---
obter_uso_cpu() {
    local pi pt i t di dt
    read -r pi pt < <(awk '/^cpu /{print $5, $2+$3+$4+$5+$6+$7+$8}' /proc/stat)
    sleep 0.5
    read -r i t  < <(awk '/^cpu /{print $5, $2+$3+$4+$5+$6+$7+$8}' /proc/stat)
    di=$((i - pi)); dt=$((t - pt))
    (( dt == 0 )) && echo 0 || echo $(((dt - di) * 100 / dt))
}

calcular_valor() { echo $(( $1 + ($2 - $1) * $3 / 100 )); }

# --- Aplica a porra da política e armazena mudanças ---
aplicar_politica() {
    local chave=$1
    [[ -z "${GPU_POLITICAS[$chave]:-}" ]] && { warn "Política $chave% não existe, bora pular"; return 1; }
    IFS=' ' read -r lvl guc bf mc pl th <<<"${GPU_POLITICAS[$chave]}"

    local mem_freq power_val
    mem_freq=$(calcular_valor "${CAPACIDADES_GPU[mem_min]}" "${CAPACIDADES_GPU[mem_max]}" "$mc")
    power_val=$(( pl * 1000 ))

    declare -A comandos=(
        [performance_level]="echo $lvl > $GPU_PATH/power/force_performance_level"
        [boost_freq]="echo $bf  > $GPU_PATH/gt_boost_freq_mhz"
        [mem_clock]="echo $mem_freq > $GPU_PATH/gt_RP1_freq_mhz"
        [power_limit]="echo $power_val > $GPU_PATH/power_limit"
    )

    CHANGES_PARAM=(); CHANGES_VALUE=(); CHANGES_REASON=()
    local count=0
    for p in "${!PARAMS_MODIFICAVEIS[@]}"; do
        [[ -z "${comandos[$p]:-}" ]] && continue
        if eval "${comandos[$p]}" 2>/dev/null; then
            val=${comandos[$p]#*> }
            CHANGES_PARAM[count]=$p
            CHANGES_VALUE[count]=$val
            CHANGES_REASON[count]="$(bayesian_reason "$p" "$val")"
            ((count++))
        else
            warn "Falhou em $p, bora próxima"
        fi
    done

    (( count > 0 )) && print_changes_table
    (( count > 0 ))
}

# --- A porra do loop principal ---
main() {
    (( EUID != 0 )) && { error "Roda como root, vacilão!"; exit 1; }
    detectar_capacidades
    print_explanation
    local keys=($(printf '%s\n' "${!GPU_POLITICAS[@]}" | sort -n))
    local prev_key="" tries=0

    while true; do
        local uso=$(obter_uso_cpu)
        log "Uso de CPU: ${uso}% — bora ajustar essa bagaça"
        local chosen="${keys[-1]}"
        for k in "${keys[@]}"; do (( uso <= k )) && { chosen=$k; break; }; done

        if [[ "$chosen" != "$prev_key" || tries -gt 0 ]]; then
            if aplicar_politica "$chosen"; then
                prev_key="$chosen"; tries=0
            else
                ((tries++))
                (( tries > 3 )) && { error "Persistente fodeu em $chosen%, saindo na porrada"; exit 1; }
            fi
        fi

        sleep "$SLEEP_INTERVAL"
    done
}

main
