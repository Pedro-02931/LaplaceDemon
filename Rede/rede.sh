#!/usr/bin/env bash

LOG_PATH="/var/log/rede-otimizador.log"
ERRORLOG=$(mktemp)

log()   { echo "[INFO]  $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_PATH"; }
warn()  { echo "[WARN]  $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_PATH"; }
error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_PATH" | tee -a "$ERRORLOG"; }

trap 'error "Linha $LINENO: comando falhou." && exit 1' ERR
set -euo pipefail

declare -A REDE_POLITICAS=(
    # dBm     txqueuelen  wmem_max  tcp_limit  tcp_rcvbuf  tcp_lowat   cc_algo  power_save
    ["-100"]="2048    16384      524288     0           16384       cubic     on"
    ["-95"]="3072    24576      786432     0           24576       cubic     on"
    ["-90"]="4096    32768      1048576    1           32768       cubic     on"
    ["-85"]="6144    49152      1572864    1           49152       bbr       off"
    ["-80"]="8192    65536      2097152    1           65536       bbr       off"
    ["-75"]="12288   98304      3145728    1           98304       bbr       off"
    ["-70"]="16384   131072     4194304    1           131072      bbr       off"
    ["-65"]="20480   163840     5242880    1           163840      bbr       off"
    ["-60"]="24576   196608     6291456    1           196608      bbr       off"
    ["-55"]="28672   229376     7340032    1           229376      bbr       off"
    ["-50"]="32768   262144     8388608    1           262144      bbr       off"
    ["-45"]="49152   393216     12582912   1           393216      bbr       off"
    ["-40"]="65535   524288     16777216   1           524288      bbr       off"
)

declare -a CHAVES_ORDENADAS

preparar_chaves() {
    CHAVES_ORDENADAS=($(printf '%s\n' "${!REDE_POLITICAS[@]}" | sort -n))
}

check_dependencies() {
    local missing=()
    command -v iw >/dev/null || missing+=("iw")
    command -v ip >/dev/null || missing+=("iproute2")
    command -v sysctl >/dev/null || missing+=("procps")
    command -v ethtool >/dev/null || missing+=("ethtool")

    if [ ${#missing[@]} -gt 0 ]; then
        warn "Dependências faltando: ${missing[*]}"
        if command -v apt-get >/dev/null; then
            apt-get update && apt-get install -y "${missing[@]}" || error "Falha na instalação"
        elif command -v dnf >/dev/null; then
            dnf install -y "${missing[@]}" || error "Falha na instalação"
        else
            error "Instale manualmente: ${missing[*]}"
            exit 1
        fi
    fi
}

detect_wifi_iface() {
    WIFI_IFACE=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}') || true
    [[ -z "${WIFI_IFACE:-}" ]] && { error "Interface Wi-Fi não detectada"; exit 1; }
    log "Interface Wi-Fi: $WIFI_IFACE"
}

get_wifi_signal_strength() {
    local strength=0
    [[ -n "${WIFI_IFACE:-}" ]] && strength=$(iw dev "$WIFI_IFACE" link 2>/dev/null | awk '/signal:/ {print $2}' || echo 0)
    echo "${strength:--100}"
}

encontrar_politica_rede() {
    local sinal=$1
    local low=0 high=$(( ${#CHAVES_ORDENADAS[@]} - 1 ))
    local mid mid_val

    while (( low <= high )); do
        mid=$(( (low + high) / 2 ))
        mid_val=${CHAVES_ORDENADAS[mid]}
        (( sinal > mid_val )) && low=$(( mid + 1 )) || high=$(( mid - 1 ))
    done

    local resultado=${CHAVES_ORDENADAS[low]}
    echo "${REDE_POLITICAS[${resultado:-40}]}"
}

apply_network_policy() {
    local sinal=$(get_wifi_signal_strength)
    (( sinal > -40 )) && sinal=-40
    (( sinal < -100 )) && sinal=-100

    IFS=' ' read -r qlen wmem tcp_limit tcp_rcvbuf tcp_lowat cc_algo power_save <<< "$(encontrar_politica_rede "$sinal")"
    
    local tentativas=(
        "ip link set $WIFI_IFACE txqueuelen $qlen"
        "ifconfig $WIFI_IFACE txqueuelen $qlen"
        "sysctl -w net.core.wmem_max=$wmem"
        "sysctl -w net.ipv4.tcp_limit_output_bytes=$tcp_limit"
        "sysctl -w net.ipv4.tcp_moderate_rcvbuf=$tcp_rcvbuf"
        "sysctl -w net.ipv4.tcp_notsent_lowat=$tcp_lowat"
        "sysctl -w net.ipv4.tcp_congestion_control=$cc_algo"
        "iwconfig $WIFI_IFACE power $power_save"
        "echo $wmem > /proc/sys/net/core/wmem_max"
    )

    for cmd in "${tentativas[@]}"; do
        eval "$cmd" && break || warn "Falha: $cmd"
    done

    log "Sinal: ${sinal}dBm → TX:$qlen WMEM:$wmem TCP_LIM:$tcp_limit TCP_RCV:$tcp_rcvbuf CC:$cc_algo PWR:$power_save"
}

main() {
    [[ $EUID -ne 0 ]] && { error "Execute como root"; exit 1; }
    log "Iniciando Otimizador de Rede"
    
    check_dependencies
    preparar_chaves
    detect_wifi_iface

    local interval=10 current_sinal last_sinal
    apply_network_policy
    last_sinal=$(get_wifi_signal_strength)

    while true; do
        apply_network_policy
        current_sinal=$(get_wifi_signal_strength)
        
        if (( last_sinal != 0 )); then
            variacao=$(( ( (last_sinal - current_sinal) * 100 ) / last_sinal ))
            variacao=${variacao#-}
            
            (( variacao > 50 )) && interval=2
            (( variacao > 20 && variacao <= 50 )) && interval=5
            (( variacao <= 20 )) && interval=10
        else
            warn "Valor inicial zero - resetando cálculo"
            variacao=0
            interval=10
        fi

        last_sinal=$current_sinal
        sleep $interval
    done
}

main