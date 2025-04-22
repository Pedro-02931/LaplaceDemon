set -euo pipefail
trap 'error "Linha $LINENO: comando falhou."' ERR

LOG_PATH="/var/vemCaPutinha.energy.log" # Garante que apenas os [ERRROR], [INFO], [WARN] sejam salvos aqui!
SCRIPT_PATH="/usr/local/bin/energy.opt.sh"
SERVICE_PATH="/etc/systemd/system/energy.opt.service"
TIMER_PATH="/etc/systemd/system/energy.opt.timer"

log()   { echo "[INFO]  $(date '+%Y-%m-%d %H:%M:%S') $*"; } # Aqui quero que verifique se o ultimo $* foi igual, se foi, ignora a linha, caso ontrario, imprima (gambiarra para compressão entrópica)
warn()  { echo "[WARN]  $(date '+%Y-%m-%d %H:%M:%S') $*"; } # Aqui quero que verifique se o ultimo $* foi igual, se foi, ignora a linha, caso ontrario, imprima (gambiarra para compressão entrópica)
error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*"; } # Quero que acione um notificador


[[ $EUID -ne 0 ]] && { error "Execute como root."; exit 1; }
log "Iniciando Otimizador de Energia/Térmica..."



check_dependencies() { # AMPLIE E INSTALE E ATIVE
    local missing=()
    command -v tlp >/dev/null || missing+=("tlp")
    command -v sensors >/dev/null || missing+=("lm-sensors")
    command -v stress-ng >/dev/null || missing+=("stress-ng")
    command -v rdmsr >/dev/null || missing+=("msr-tools")
    command -v wrmsr >/dev/null || missing+=("msr-tools")
    if [ ${#missing[@]} -gt 0 ]; then
        warn "Dependências faltando: ${missing[*]}"
        apt-get update && apt-get install -y "${missing[@]}" || error "Falha na instalação"
        systemctl enable --now tlp 2>/dev/null || true
        sensors-detect --auto 2>/dev/null || true
    fi
    log "Habilitando systemctls..."
    {
    systemctl enable --now thermald
    systemctl enable --now tlp
    # Quero que habilite tudo relaconado
    } || error "Falha ao habilitar"
}

###############################################


declare -A HOLISTIC_POLICIES=(
    # Uso%  | CPU Gov       | GPU Perf | Disk APM | USB Suspend  | Cores | EPB | ZRAM% | Algoritmo | Streams | Swappiness | VRAM Clock | Power Limit | Boost Freq
    ["000"]="powersave       low        max        1              0       0A    5       zstd        1         10           300          20            8"
    ["005"]="powersave       low        med        1              1       0A    10      zstd        1         15           350          25            10"
    ["010"]="powersave       low        med        2              2       0A    15      lz4         2         20           400          30            12"
    ["020"]="powersave       low        med        2              3       08    20      lz4         2         25           450          35            14"
    ["030"]="ondemand        medium     med        3              4       08    25      lzo         3         30           500          40            16"
    ["040"]="ondemand        medium     med        3              5       06    30      zstd        3         35           550          45            18"
    ["050"]="conservative    medium     low        4              6       06    35      lz4         4         40           600          50            20"
    ["060"]="conservative    high       low        4              7       04    40      lzo         4         45           650          55            22"
    ["070"]="performance     high       low        5              8       04    45      zstd        5         50           700          60            24"
    ["080"]="performance     high       min        5              9       02    50      lz4         5         55           750          65            26"
    ["090"]="performance     high       min        6              10      02    55      zstd        6         60           800          70            28"
    ["100"]="performance     high       min        6              11      02    60      zstd        6         65           900          80            30"
)

get_system_status() {
local policy_key="$1"
    local usage=$(printf "%d" "$policy_key")
    local mismatch=0
    local MAX_FREQ_STATES=30
    local STATE_FILE="/var/vemCaPutinha.harmonic.CPU_USAGE.state"
    local LOG_FILE="/var/vemCaPutinha.harmonic.CPU_USAGE.log"

    ##########################################
    # COLETA DE DADOS DE TODAS AS CPUS
    local total_cur=0 total_min=0 total_max=0 count=0
    local -A freq_states

    for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
        [[ -f "$cpu_dir/cpufreq/scaling_cur_freq" ]] || continue
        [[ -f "$cpu_dir/cpufreq/scaling_min_freq" ]] || continue
        [[ -f "$cpu_dir/cpufreq/scaling_max_freq" ]] || continue

        local cur=$(< "$cpu_dir/cpufreq/scaling_cur_freq")
        local min=$(< "$cpu_dir/cpufreq/scaling_min_freq")
        local max=$(< "$cpu_dir/cpufreq/scaling_max_freq")

        (( cur < min || cur > max || max == min )) && continue

        total_cur=$(( total_cur + cur ))
        total_min=$(( total_min + min ))
        total_max=$(( total_max + max ))
        count=$(( count + 1 ))

        freq_states["${cur}:${min}:${max}"]=1
    done

    (( count == 0 )) && echo "[DEBUG] Nenhuma CPU legível." >&2 && return 0

    local avg_cur=$(( total_cur / count ))
    local avg_min=$(( total_min / count ))
    local avg_max=$(( total_max / count ))

    local usage_pct=$(( 100 * (avg_cur - avg_min) / (avg_max - avg_min) ))
    echo "[DEBUG] Média de uso atual da CPU: ${usage_pct}% (Base: ${usage}%)" >&2

    ##########################################
    # SALVA O USO NO HISTÓRICO
    local -a measures=()
    [[ -f "$STATE_FILE" ]] && mapfile -t measures < "$STATE_FILE"
    measures+=("$usage_pct")

    local cores=$(nproc --all)
    local HARMONIC_N=$(( cores < 3 ? 3 : (cores > 10 ? 10 : cores) ))
    (( ${#measures[@]} > HARMONIC_N )) && measures=("${measures[@]: -HARMONIC_N}")

    local sum=0 max=${measures[0]:-0}
    for v in "${measures[@]}"; do
        (( sum += v ))
        (( v > max )) && max=$v
    done
    local avg=$(( sum / ${#measures[@]} ))

    echo "[DEBUG] Média harmônica do histórico: ${avg}% (Histórico: ${#measures[@]} entradas)" >&2

    printf "%s\n" "${measures[@]}" > "$STATE_FILE"

    ##########################################
    # VERIFICAÇÃO DE DIFERENÇA ENTRE MÉDIA E CHAVE
    local tolerance=5
    if (( avg < usage - tolerance || avg > usage + tolerance )); then
        echo "[DEBUG] Média fora da faixa tolerada (±${tolerance}%) → mismatch." >&2
        mismatch=1
    fi

    ##########################################
    # HOLOGRAMA DE ESTADOS
    local state_count=${#freq_states[@]}
    if (( state_count > MAX_FREQ_STATES )); then
        echo "[DEBUG] Estados holográficos excedem o limite: ${state_count}/${MAX_FREQ_STATES}" >&2
        mismatch=1
    fi

    ##########################################
    return $(( mismatch == 0 ? 1 : 0 ))
}

governor_apply() {
    local target_gov="$1"
    local changed=0 total=0
    local available_govs

    if command -v cpupower &>/dev/null; then
        available_govs=$(cpupower frequency-info -g | tr -d '[:cntrl:]')
    else
        available_govs=$(</sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors)
    fi

    # Verificar se o governador é válido
    if [[ ! "$available_govs" =~ (^| )"$target_gov"( |$) ]]; then
        error "Governador inválido: $target_gov. Disponíveis: $available_govs"
        return 0  
    fi

    # Aplicar para todos os núcleos
    for cpu in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
        ((total++))
        local current_gov=$(<"$cpu/scaling_governor")

        if [[ "$current_gov" == "$target_gov" ]]; then
            continue
        fi

        if command -v cpupower &>/dev/null; then
            local core_id=$(basename "$(dirname "$cpu")" | grep -o '[0-9]\+')
            cpupower -c "$core_id" frequency-set -g "$target_gov" &>/dev/null \
                && ((changed++)) \
                || warn "Falha cpupower $target_gov em core $core_id"
        else
            if printf "%s" "$target_gov" > "$cpu/scaling_governor" 2>/dev/null; then
                ((changed++))
            else
                warn "Falha ao aplicar $target_gov em ${cpu%/*} (Permissão? Hardware?)"
            fi
        fi
    done

    # Log otimizado com compressão de estado
    if ((changed > 0)); then
        log "Governador atualizado: $target_gov em $changed/$total cores"
    else
        log "Governador mantido: $target_gov (já ativo em todos os cores)"
    fi
}


gpu_dpm() {
    local perf="$1" vram="$2" pwr="$3" boost="$4"
    local intel_gpu="/sys/class/drm/card0/device"

    # Performance state
    if [[ -w "$intel_gpu/power_dpm_state" ]]; then
        local state_val
        case "$perf" in
            "low")    state_val="battery" ;;
            "medium") state_val="balanced" ;;
            "high")   state_val="performance" ;;
        esac
        safe_write "$state_val" "$intel_gpu/power_dpm_state"
    fi

    # Frequência Máxima da GPU
    if [[ -r "$intel_gpu/gt_RP0_freq_mhz" && -w "$intel_gpu/gt_max_freq_mhz" && -n "$vram" ]]; then
        local rp0=$(< "$intel_gpu/gt_RP0_freq_mhz")
        local safe_vram=$(( vram > rp0 ? rp0 : vram ))
        safe_write "$safe_vram" "$intel_gpu/gt_max_freq_mhz"
    fi

    # Power Limit (TDP)
    if [[ -n "$pwr" && -w "$intel_gpu/pl1_power_limit" && -w "$intel_gpu/pl2_power_limit" ]]; then
        local new_pwr=$(( pwr * 1000 ))  # mW
        safe_write "$new_pwr" "$intel_gpu/pl1_power_limit"
        safe_write "$new_pwr" "$intel_gpu/pl2_power_limit"
    fi

    # Boost da GPU
    if [[ -w "$intel_gpu/gt_boost_freq_mhz" && -n "$boost" ]]; then
        safe_write "$boost" "$intel_gpu/gt_boost_freq_mhz"
    fi

    log_info "GPU configurada: perf=$perf | freq=${vram}MHz | TDP=${pwr}W | boost=${boost}MHz"
}

<< EOF FUNCOES
main() {
    get_system_status

    IFS=' ' read -r cpu_gov gpu_mode disk_apm usb_pol cores epb zram_perc zram_alg zram_str swappiness vram_clk pwr_limit boost <<< "${HOLISTIC_POLICIES[$chave]}"
    governor_apply "$cpu_gov" ##########
    gpu_dpm "$gpu_mode" "$vram_clk" "$pwr_limit" "$boost" #############
    configurar_apm_disco "$disk_apm"
    gerenciar_usb_power "$usb_pol"
    otimizar_zram "$zram_perc" "$zram_alg" "$zram_str"
    aplicar_energy_bias "$epb"
    ativar_cores "$cores"
    ajustar_swappiness "$swappiness"
}
EOF




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
