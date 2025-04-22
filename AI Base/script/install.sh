#!/bin/bash
set -euo pipefail
trap 'error "Linha $LINENO: comando falhou."' ERR

LOG_PATH="/var/vemCaPutinha.energy.log"   # Apenas [ERROR], [WARN], [INFO]
SCRIPT_PATH="/usr/local/bin/energy.opt.sh"
SERVICE_PATH="/etc/systemd/system/energy.opt.service"
TIMER_PATH="/etc/systemd/system/energy.opt.timer"

# Variáveis para compressão entrópica
declare LAST_LOG="" LAST_WARN=""

log() {
    local msg="$*"
    [[ "$msg" == "$LAST_LOG" ]] && return
    LAST_LOG="$msg"
    printf "[INFO]  %s %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$msg" >> "$LOG_PATH"
}

warn() {
    local msg="$*"
    [[ "$msg" == "$LAST_WARN" ]] && return
    LAST_WARN="$msg"
    printf "[WARN]  %s %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$msg" >> "$LOG_PATH"
}

error() {
    local msg="$*"
    printf "[ERROR] %s %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$msg" >> "$LOG_PATH"
    # dispara notificação de desktop (se disponível)
    command -v notify-send &>/dev/null && notify-send "[$(basename "$0")] ERRO" "$msg"
}

[[ $EUID -ne 0 ]] && { error "Execute como root."; exit 1; }
log "Iniciando Otimizador de Energia/Térmica..."

check_dependencies() {
    local missing=()
    for pkg in tlp lm-sensors stress-ng msr-tools; do
        command -v "${pkg%%-*}" &>/dev/null || missing+=("$pkg")
    done
    if (( ${#missing[@]} )); then
        warn "Dependências faltando: ${missing[*]}"
        apt-get update && apt-get install -y "${missing[@]}" || error "Falha na instalação"
    fi

    log "Habilitando serviços necessários..."
    systemctl enable --now thermald tlp 2>/dev/null || warn "Falha ao habilitar thermald/tlp"
    sensors-detect --auto 2>/dev/null || warn "sensors-detect não pôde rodar"
}

declare -A HOLISTIC_POLICIES=(
    # Uso%  | CPU Gov       | GPU Perf  | Cores | EPB | ZRAM% | Algoritmo | Streams | Swappiness | VRAM Clock | Power Limit | Boost Freq | GPU Clock (MHz) | TDP Limit (W) | Boost Clock (MHz)
    ["000"]="powersave       battery     0       0A    5       zstd        1         10           300          20            8           300              15             300"
    ["005"]="powersave       battery     1       0A    10      zstd        1         15           350          25            10          350              18             400"
    ["010"]="powersave       battery     2       0A    15      lz4         2         20           400          30            12          450              20             500"
    ["020"]="powersave       balanced    3       08    20      lz4         2         25           450          35            14          600              22             600"
    ["030"]="ondemand        balanced    4       08    25      lzo         3         30           500          40            16          750              25             800"
    ["040"]="ondemand        balanced    5       06    30      zstd        3         35           550          45            18          900              28             900"
    ["050"]="conservative    balanced    6       06    35      lz4         4         40           600          50            20          900              30             950"
    ["060"]="conservative    balanced    7       04    40      lzo         4         45           650          55            22          950              32             1000"
    ["070"]="performance     performance 8       04    45      zstd        5         50           700          60            24          1000             35             1050"
    ["080"]="performance     performance 9       02    50      lz4         5         55           750          65            26          1050             38             1100"
    ["090"]="performance     performance 10      02    55      zstd        6         60           800          70            28          1100             40             1150"
    ["100"]="performance     performance 11      02    60      zstd        6         65           900          80            30          1150             45             1150"
)


get_system_status() {
    local policy_key="$1"
    local usage="$(printf "%d" "$policy_key")"
    local mismatch=0 MAX_STATES=30
    local STATE_FILE="/var/vemCaPutinha.harmonic.CPU_USAGE.state"

    # Coleta e cálculo de uso médio
    local total_cur=0 total_min=0 total_max=0 count=0
    declare -A freq_states
    for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
        [[ -r "$cpu_dir/cpufreq/scaling_cur_freq" ]] || continue
        local cur min max
        cur=$(<"$cpu_dir/cpufreq/scaling_cur_freq")
        min=$(<"$cpu_dir/cpufreq/scaling_min_freq")
        max=$(<"$cpu_dir/cpufreq/scaling_max_freq")
        (( cur<min || cur>max || max==min )) && continue
        (( total_cur+=cur, total_min+=min, total_max+=max, count++ ))
        freq_states["$cur:$min:$max"]=1
    done
    (( count==0 )) && echo "[DEBUG] Nenhuma CPU legível." >&2 && return 0

    local avg_cur=$(( total_cur/count ))
    local avg_min=$(( total_min/count ))
    local avg_max=$(( total_max/count ))
    local usage_pct=$(( 100*(avg_cur-avg_min)/(avg_max-avg_min) ))

    # Histórico harmônico
    mapfile -t measures < <( [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE" ) 
    measures+=("$usage_pct")
    local cores=$(nproc)
    local N=$(( cores<3?3: cores>10?10:cores ))
    (( ${#measures[@]}>N )) && measures=("${measures[@]: -N}")

    local sum=0 max=${measures[0]}
    for v in "${measures[@]}"; do (( sum+=v )); (( v>max && max=v )); done
    local avg=$(( sum/${#measures[@]} ))
    printf "%s\n" "${measures[@]}" > "$STATE_FILE"

    # Verifica tolerância e estados
    (( ${#freq_states[@]}>MAX_STATES || avg < usage-5 || avg > usage+5 )) && mismatch=1
    return $(( mismatch==0 ? 1 : 0 ))
}

governor_apply() {
    local target="$1" changed=0 total=0
    local govs
    if command -v cpupower &>/dev/null; then
        govs=$(cpupower frequency-info -g)
    else
        govs=$(< /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors)
    fi

    [[ ! " $govs " =~ " $target " ]] && { error "Governador inválido: $target"; return; }

    for cpu in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
        (( total++ ))
        local cur=$(<"$cpu/scaling_governor")
        [[ "$cur" == "$target" ]] && continue
        if command -v cpupower &>/dev/null; then
            local id=${cpu##*cpu}
            cpupower -c "$id" frequency-set -g "$target" &>/dev/null && ((changed++)) \
                || warn "Falha cpupower em core $id"
        else
            printf "%s" "$target" > "$cpu/scaling_governor" 2>/dev/null && ((changed++)) \
                || warn "Falha ao setar $target em ${cpu%/*}"
        fi
    done

    if (( changed )); then
        log "Governador atualizado: $target em $changed/$total cores"
    else
        log "Governador mantido: $target"
    fi
}

gpu_dpm() {
    local perf="$1" vram="$2" pwr="$3" boost="$4"
    local d="/sys/class/drm/card0/device"
    safe_write() { printf "%s" "$1" >"$2" 2>/dev/null; }

    [[ -w "$d/power_dpm_state" ]] && {
        local st=${perf//battery/low}
        safe_write "${st/balanced/medium}" "$d/power_dpm_state"
    }
    [[ -w "$d/gt_max_freq_mhz" ]] && safe_write "$vram" "$d/gt_max_freq_mhz"
    [[ -w "$d/pl1_power_limit" ]] && {
        local mw=$((pwr*1000))
        safe_write "$mw" "$d/pl1_power_limit"
        safe_write "$mw" "$d/pl2_power_limit"
    }
    [[ -w "$d/gt_boost_freq_mhz" ]] && safe_write "$boost" "$d/gt_boost_freq_mhz"
    log "GPU: perf=$perf freq=${vram}MHz TDP=${pwr}W boost=${boost}MHz"
}

zram_opt() {
    local pct="$1" alg="$2" str="$3"
    modprobe zram
    local mem_kb=$(awk '/MemTotal/{print $2}' /proc/meminfo)
    for i in $(seq 0 $((str-1))); do
        echo $i > /sys/class/zram-control/hot_add
        echo "$alg" > /sys/block/zram$i/comp_algorithm
        echo "$((mem_kb/1024*pct/100/str))M" > /sys/block/zram$i/disksize
        mkswap /dev/zram$i
        swapon /dev/zram$i
    done
}

energy_opt() {
    local th="$1" epb="$2"
    local cur=$(rdmsr -r 0x1b0 2>/dev/null | awk '{printf "%02X",$1}') || return
    [[ "$cur" != "$epb" ]] && wrmsr -a 0x1b0 $((16#$epb)) 2>/dev/null || true

    IFS=' ' read -r cpu_gov gpu_mode disk_apm usb_suspend radio_pol cores _ epb_read <<< "${HOLISTIC_POLICIES[$th]}"
    log "Aplicando Perfil ${th}% TjMax: CPU=$cpu_gov GPU=$gpu_mode DISCO=$disk_apm USB=$usb_suspend RÁDIO=$radio_pol NÚCLEOS=$cores EPB=$epb_read"
    if [[ "${POWER_STATE:-AC}" == "AC" ]]; then
        tlp ac --CPU_SCALING_GOVERNOR_ON_AC="$cpu_gov" --RADEON_DPM_STATE_ON_AC="$gpu_mode" --SATA_LINKPWR_ON_AC="max_performance"
    else
        tlp bat --CPU_SCALING_GOVERNOR_ON_BAT="$cpu_gov" --RADEON_DPM_STATE_ON_BAT="$gpu_mode" --SATA_LINKPWR_ON_BAT="$disk_apm" --USB_AUTOSUSPEND="$usb_suspend"
    fi
    tlp start >/dev/null
}

ajustar_swappiness() {
    sysctl -w vm.swappiness="$1" >/dev/null
    log "Swappiness ajustado: $1"
}

main() {
    check_dependencies
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') Iniciando monitoramento automático (colapso habilitado)…"

    local CURRENT_KEY=""

    while true; do
        for key in "${!HOLISTIC_POLICIES[@]}"; do
            get_system_status "$key"
            if (( $? == 1 )); then
                if [[ "$key" != "$CURRENT_KEY" ]]; then
                    IFS=' ' read -r cpu_gov perf disk_apm usb_suspend radio_pol cores _ \
                                     epb zram_pct zram_alg zram_str swappiness \
                                     vram pwr boost \
                        <<< "${HOLISTIC_POLICIES[$key]}"

                    # imprime no terminal todas as mudanças de uma vez
                    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') Aplicando perfil $key (antes: ${CURRENT_KEY:-nenhum}):"
                    echo "       CPU governor=$cpu_gov | GPU perf=$perf freq=${vram}MHz TDP=${pwr}W boost=${boost}MHz"
                    echo "       ZRAM=${zram_pct}% alg=${zram_alg} streams=${zram_str} | Swappiness=$swappiness | EPB=$epb | Cores=$cores"

                    governor_apply      "$cpu_gov"
                    gpu_dpm             "$perf" "$vram" "$pwr" "$boost"
                    zram_opt            "$zram_pct" "$zram_alg" "$zram_str"
                    energy_opt          "$key" "$epb"
                    ajustar_swappiness  "$swappiness"

                    CURRENT_KEY="$key"
                else
                    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') Perfil $key já ativo; nenhuma alteração necessária"
                fi
                break
            fi
        done
        sleep 30
    done
}

main "$@"


main "$@"




<< EOF REAMES
Beleza, bora fazer esse **merge entre tecnologia hardcore, controle de energia e performance holística**. Aqui vai um resumo detalhado — **lógico, eletrônico e com nomenclatura** — de cada item citado na tua tabela, mais os conceitos extras que você listou. Tudo explicado com pegada técnica, mas direto:

---

## 🔧 **TABELA DE COMPONENTES / CONCEITOS**

| Nome                 | O que é (Lógico)                                                                 | Eletrônico / Físico                                                  | Observações / Nomenclatura                                                                 |
|----------------------|----------------------------------------------------------------------------------|----------------------------------------------------------------------|---------------------------------------------------------------------------------------------|
| **CPU Gov**          | Governador de frequência do processador (software)                              | Controla frequência dos clocks da CPU por software                   | Ex: `powersave`, `ondemand`, `performance`, `schedutil`                                     |
| **GPU Perf**         | Nível de performance da GPU (DPM - Dynamic Power Mgmt)                          | Ajusta tensão/frequência da GPU (via sysfs ou driver)                | Ex: `low`, `med`, `high`, `min` (alguns drivers têm valores de 1 a 7)                       |
| **Disk APM**         | Advanced Power Management (para HDs/SSDs)                                       | Controla rotação/sleep do disco via ATA/ACPI                         | Nível 1 = máximo desempenho, 255 = economia máxima                                          |
| **Radio**            | Gerencia Wi-Fi e Bluetooth (ativar/desativar/modo)                              | Habilita/disabilita interfaces como `wlan0`, `bluetooth0`, etc       | `802.11n/ac/ax`, `Bluetooth UWB`, ou modo avião                                             |
| **EPB**              | Energy Performance Bias (controla consumo vs. performance)                      | Registro MSR (Model-Specific Register)                               | Hex de 0x0 (performance) até 0xF (eficiência)                                               |
| **ZRAM**             | RAM comprimida como swap                                                        | Simula disco swap em memória RAM com compressão                      | Percentual da RAM usada como zram + algoritmo (`zstd`, `lz4`, `lzo`, etc)                   |
| **Streams**          | Número de threads simultâneas que o sistema vai permitir (ex: encoding, IO)     | Controla paralelismo lógico                                          | Pode refletir na divisão de tarefas, como em encoders, downloads, IOs                       |
| **Swappiness**       | Propensão do kernel a usar swap                                                 | Controla com que frequência a memória é despejada                    | Escala de 0 (evitar swap) a 100 (usar swap agressivamente)                                  |
| **VRAM Clock**       | Frequência da memória de vídeo                                                  | Regula o clock da VRAM (GDDR5/6)                                     | Mais clock = mais desempenho e mais calor                                                   |
| **Power Limit**      | Limite de potência para a GPU ou CPU                                            | Define o TDP (Thermal Design Power) do componente                    | Geralmente configurado via `power1_cap` ou drivers como `nvidia-smi`                        |
| **Boost Freq**       | Overclock momentâneo quando há carga intensa (Turbo Boost)                      | Aumenta clock acima do nominal, se térmica e energia permitirem      | Pode ser removido se já estiver controlando `governor`, `power_limit` e `EPB`               |

---

## ⚙️ CONCEITOS AVANÇADOS

| Conceito                  | Explicação                                                                                                     |
|---------------------------|-----------------------------------------------------------------------------------------------------------------|
| **Interpolação Exponencial** | Interpolação onde valores intermediários crescem de forma exponencial (ex: consumo, resposta térmica)          |
| **Underclock**            | Redução da frequência de operação de CPU/GPU para economizar energia ou reduzir aquecimento                   |
| **802.11n/ac/ax**         | Padrões Wi-Fi. `n` = até 600Mbps, `ac` = até 1.3Gbps, `ax` (Wi-Fi 6) = até 9.6Gbps. Impactam latência e energia |
| **Bluetooth UWB**         | Ultra-Wideband – baixa latência, alta precisão para localização e dados em curto alcance                       |

---

## 🧠 SOBRE A TABELA ESTRUTURADA COM GRANULARIDADE DE 5%

Sua tabela é genial. Ela sintetiza a ideia de um **sistema adaptativo responsivo** a múltiplas camadas:

- **Política reativa por carga** (% de uso → perfil energético)
- **Matriz de estados multidimensionais** (cada valor tem implicações cruzadas)
- **Alto controle sob o kernel e os barramentos** (`/sys`, `cpufreq`, `zramctl`, etc.)

### Você perguntou sobre remover **Boost Freq**:
> 💡 Se você já está controlando `CPU Gov`, `EPB` e `Power Limit`, então o `Boost` é **redundante**.  
Você pode manter para controle fino, mas se quiser simplificar e evitar conflito entre camadas, pode remover sim.

---

Se quiser posso montar um `.dtsi` simbólico com essa estrutura pra facilitar debug e visualização em árvore (como o device tree do Linux), ou mesmo criar um gráfico em `mermaid`/`graphviz` com os fluxos de política. Quer?
EOF
