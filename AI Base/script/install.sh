#!/bin/bash

set -euo pipefail
trap 'error "Erro na linha $LINENO: Comando falhou."' ERR

readonly LOG_PATH="/var/log/vemCaPutinha.energy.log"
readonly VERIFICATION_LOG="/var/opt/vemCaMeuUrsinhoPervertido.log"
readonly HISTORY_FILE="/var/opt/vemCaPutinha.harmonic.CPU_USAGE.state"
readonly STATUS_FILE="/var/opt/energy_opt_status"
readonly SCRIPT_PATH="/usr/local/bin/energy_opt.sh"
readonly SERVICE_PATH="/etc/systemd/system/energy_opt.service"
readonly TIMER_PATH="/etc/systemd/system/energy_opt.timer"
readonly MAX_HISTORY=15
readonly EMA_ALPHA=0.3
readonly CRITICAL_TEMP_THRESHOLD=85000
readonly HIGH_LOAD_THRESHOLD=75
readonly LOW_LOAD_THRESHOLD=20
readonly MIN_SLEEP_INTERVAL=15
readonly MAX_SLEEP_INTERVAL=120

declare -A HOLISTIC_POLICIES=(
    ["01000"]="powersave       battery     1       0A    10      zstd        1         15           350          25            10"
    ["03000"]="powersave       battery     3       0A    20      lz4         2         25           450          35            14"
    ["00010"]="powersave       battery     0       0F    5       zstd        1         10           300          20             8"
    ["01001"]="ondemand        balanced    5       06    30      zstd        3         35           550          45            18"
    ["05001"]="conservative    balanced    6       06    35      lz4         4         40           600          50            20"
    ["08001"]="performance     performance 9       02    50      lz4         5         55           750          65            26"
    ["10001"]="performance     performance 11      00    60      zstd        6         65           900          80            30"
    ["00011"]="conservative    balanced    4       0A    25      lz4         2         30           500          40            16"
)

declare -A SAFE_LIMITS=(
    [TDP]=50
    [VRAM_CLOCK]=1500
    [BOOST_CLOCK]=1800
    [CPU_TEMP]=95000
)

declare -A EXECUCOES
declare CURRENT_POLICY_KEY=""
declare CURRENT_EMA=0
declare MODIFIED=0
declare LAST_LOG_MSG=""

_log_base() {
    local type="$1" msg="$2" timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local full_msg="[$type] $timestamp: $msg"
    if [[ "$full_msg" != "$LAST_LOG_MSG" ]]; then
        echo "$full_msg" >> "$LOG_PATH"
        [[ -t 1 || -t 2 ]] && echo "$full_msg"
        LAST_LOG_MSG="$full_msg"
    fi
}

log() { _log_base "INFO" "$1"; }
warn() { _log_base "WARN" "$1"; }
error() { _log_base "ERROR" "$1"; } >&2

load_execution_status() {
    if [[ -f "$VERIFICATION_LOG" ]]; then
        while IFS='|' read -r key value; do
            [[ -n "$key" ]] && EXECUCOES["$key"]="$value"
        done < "$VERIFICATION_LOG"
        log "Carregado status de execução anterior de $VERIFICATION_LOG."
    else
        touch "$VERIFICATION_LOG"
        chmod 640 "$VERIFICATION_LOG"
        chown root:root "$VERIFICATION_LOG"
        log "Arquivo de log de verificação $VERIFICATION_LOG criado."
    fi
}

registrar_execucao() {
    local chave="$1" valor="$2" temp_log="/tmp/verification_log.$$"
    EXECUCOES["$chave"]="$valor"
    : > "$temp_log"
    for k in "${!EXECUCOES[@]}"; do
        printf "%s|%s\n" "$k" "${EXECUCOES[$k]}" >> "$temp_log"
    done
    mv "$temp_log" "$VERIFICATION_LOG"
    log "Status de execução registrado: $chave = $valor"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Este script precisa ser executado como root."
        registrar_execucao "CHECK_ROOT" "0"
        exit 1
    else
        registrar_execucao "CHECK_ROOT" "1"
    fi
}

check_dependencies() {
    local missing=() critical_missing=0 packages_installed=0
    local critical_pkgs=("msr-tools" "util-linux")
    local optional_pkgs=("tlp" "lm-sensors" "cpupower" "zram-tools" "preload")

    log "Verificando dependências..."
    for pkg in "${critical_pkgs[@]}" "${optional_pkgs[@]}"; do
        local cmd_name=${pkg%%-*}
        [[ "$cmd_name" == "util-linux" ]] && cmd_name="mkswap"
        [[ "$cmd_name" == "preload" ]] && cmd_name="preload"
        if ! command -v "$cmd_name" &>/dev/null; then
            local is_critical=0
            for critical in "${critical_pkgs[@]}"; do [[ "$pkg" == "$critical" ]] && is_critical=1 && break; done
            if [[ $is_critical -eq 1 ]]; then critical_missing=1; fi
            missing+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Dependências faltantes: ${missing[*]}"
        if command -v apt-get &>/dev/null; then
           if apt-get update >/dev/null && apt-get install -y "${missing[@]}"; then
               log "Dependências instaladas com sucesso: ${missing[*]}"
               packages_installed=1
           else
               error "Falha ao instalar dependências com apt-get."
           fi
        else
           error "apt-get não encontrado. Instale manualmente: ${missing[*]}"
        fi
    fi

    if [[ $critical_missing -eq 1 ]] && [[ $packages_installed -eq 0 ]]; then
       error "Dependências críticas ausentes e falha na instalação. Abortando."
       registrar_execucao "DEPENDENCIAS" "0"
       exit 1
    fi

    if command -v preload &>/dev/null; then
       if systemctl is-enabled preload &>/dev/null && systemctl is-active preload &>/dev/null; then
          log "Serviço preload já está ativo e habilitado."
       else
          log "Habilitando e iniciando o serviço preload..."
          systemctl enable --now preload &>/dev/null || warn "Falha ao habilitar/iniciar preload."
       fi
    fi
    
    registrar_execucao "DEPENDENCIAS" "1"
    log "Verificação de dependências concluída."
}

optimize_kernel_sched() {
    local success=1
    log "Otimizando parâmetros do kernel para escalonamento..."
    sysctl -w kernel.sched_migration_cost_ns=5000000 >/dev/null || { warn "Falha ao definir sched_migration_cost_ns"; success=0; }
    sysctl -w kernel.sched_autogroup_enabled=0 >/dev/null || { warn "Falha ao definir sched_autogroup_enabled"; success=0; }
    sysctl -w vm.dirty_ratio=10 >/dev/null || { warn "Falha ao definir vm.dirty_ratio"; success=0; }

    if [[ $success -eq 1 ]]; then
       log "Parâmetros do kernel ajustados."
       registrar_execucao "KERNEL_OPTIMIZATION" "1"
    else
       log "Falha ao ajustar alguns parâmetros do kernel."
       registrar_execucao "KERNEL_OPTIMIZATION" "0"
    fi
}

get_cpu_usage() {
    local usage avg_idle last_idle current_idle diff_idle
    local last_total current_total diff_total last_usage cpu_line
    local stat_hist_file="${HISTORY_FILE}.stat"

    cpu_line=$(grep '^cpu ' /proc/stat)
    read -r _ last_user last_nice last_system last_idle last_iowait last_irq last_softirq _ _ < <(grep '^cpu ' "$stat_hist_file" 2>/dev/null || echo "cpu 0 0 0 0 0 0 0 0 0")
    read -r _ current_user current_nice current_system current_idle current_iowait current_irq current_softirq _ _ < <(echo "$cpu_line")
    
    echo "$cpu_line" > "$stat_hist_file"

    last_total=$((last_user + last_nice + last_system + last_idle + last_iowait + last_irq + last_softirq))
    current_total=$((current_user + current_nice + current_system + current_idle + current_iowait + current_irq + current_softirq))
    
    diff_idle=$((current_idle - last_idle))
    diff_total=$((current_total - last_total))

    if (( diff_total > 0 )); then
        usage=$(( (1000 * (diff_total - diff_idle) / diff_total + 5) / 10 ))
    else
        usage=0
    fi
    
    echo "$usage"
}

get_cpu_temp() {
    local temp temp_file max_temp=0
    for temp_file in /sys/class/thermal/thermal_zone*/temp; do
        if [[ -r "$temp_file" ]]; then
            temp=$(<"$temp_file")
            if [[ "$temp" =~ ^[0-9]+$ ]] && (( temp > 0 && temp < 120000 )); then
               (( temp > SAFE_LIMITS[CPU_TEMP] )) && warn "Temperatura da CPU ($((temp/1000))C) excedeu limite seguro (${SAFE_LIMITS[CPU_TEMP]/1000}C)!"
               (( temp > max_temp )) && max_temp=$temp
            fi
        fi
    done
    [[ "$max_temp" -eq 0 ]] && warn "Não foi possível ler nenhuma temperatura válida da CPU."
    echo "$max_temp"
}

get_power_source() {
    if compgen -G "/sys/class/power_supply/AC*/online" > /dev/null; then
       for ac_file in /sys/class/power_supply/AC*/online; do
           if [[ -r "$ac_file" ]] && [[ $(<"$ac_file") == "1" ]]; then echo "1"; return; fi
       done
    elif compgen -G "/sys/class/power_supply/ADP*/online" > /dev/null; then
       for adp_file in /sys/class/power_supply/ADP*/online; do
           if [[ -r "$adp_file" ]] && [[ $(<"$adp_file") == "1" ]]; then echo "1"; return; fi
       done
    fi
    echo "0"
}

get_current_governor() {
    local gov_file="/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
    [[ -r "$gov_file" ]] && cat "$gov_file" || echo "unknown"
}
get_current_swappiness() {
    sysctl -n vm.swappiness 2>/dev/null || echo "-1"
}
get_current_epb() {
    local epb_hex
    if command -v rdmsr &>/dev/null; then
       epb_hex=$(rdmsr -f 3:0 0x1b0 2>/dev/null) || epb_hex="00"
       printf "%02X" "$((16#$epb_hex))"
    else echo "00"; fi
}

faz_o_urro() {
    local current_metric="$1"
    local -a history=()
    local count=0 i=0 start_index

    [[ -f "$HISTORY_FILE" ]] && mapfile -t history < "$HISTORY_FILE"

    history+=("$current_metric")
    count=${#history[@]}

    if (( count > MAX_HISTORY )); then
        start_index=$((count - MAX_HISTORY))
        history=("${history[@]:$start_index}")
        count=$MAX_HISTORY
    fi

    CURRENT_EMA=$(awk -v cv="$current_metric" -v a="$EMA_ALPHA" -v pe="$CURRENT_EMA" 'BEGIN {printf "%.0f", a * cv + (1 - a) * pe}')
    
    printf "%s\n" "${history[@]}" > "$HISTORY_FILE"
}


determine_policy_key() {
    local cpu_usage temp power_source temp_critical_flag key fallback_key best_match_key key_usage diff min_diff k
    cpu_usage=$(get_cpu_usage)
    temp=$(get_cpu_temp)
    power_source=$(get_power_source)

    faz_o_urro "$cpu_usage"

    (( temp >= CRITICAL_TEMP_THRESHOLD )) && temp_critical_flag=1 || temp_critical_flag=0

    local usage_key
    printf -v usage_key "%03d" "$CURRENT_EMA"

    key="${usage_key}${temp_critical_flag}${power_source}"

    if [[ -v HOLISTIC_POLICIES["$key"] ]]; then
        echo "$key"
        return
    fi

    fallback_key=""
    if [[ "$temp_critical_flag" -eq 1 ]]; then
        for k in "${!HOLISTIC_POLICIES[@]}"; do
            if [[ "${k:3:1}" == "1" ]] && [[ "${k:4:1}" == "$power_source" ]]; then
                fallback_key="$k"; break
            fi
        done
    else
        best_match_key="" min_diff=999
        for k in "${!HOLISTIC_POLICIES[@]}"; do
           if [[ "${k:3:1}" == "0" ]] && [[ "${k:4:1}" == "$power_source" ]]; then
              key_usage=$((10#${k:0:3}))
              diff=$(( CURRENT_EMA - key_usage ))
              (( diff < 0 )) && diff=$(( -diff ))
              if (( diff < min_diff )); then
                 min_diff=$diff
                 best_match_key="$k"
              fi
           fi
        done
        fallback_key="$best_match_key"
    fi
    
    if [[ -n "$fallback_key" ]]; then
       warn "Chave exata '$key' não encontrada. Usando fallback mais próximo: '$fallback_key'"
       echo "$fallback_key"
    else
       warn "Nenhuma política encontrada para o estado atual (Chave: $key). Mantendo estado anterior."
       echo "$CURRENT_POLICY_KEY"
    fi
}

governor_apply() {
    local target_gov="$1" current_gov changed=0 total_cores=0 cpu_path gov_path cpu_id available_govs
    if ! command -v cpupower &>/dev/null && [[ ! -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then return; fi
    if [[ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ]]; then available_govs=$(< /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors); elif command -v cpupower &>/dev/null; then available_govs=$(cpupower frequency-info -g 2>/dev/null) || available_govs=""; else available_govs=""; fi
    [[ -z "$available_govs" ]] && return
    [[ ! " $available_govs " =~ " $target_gov " ]] && { warn "Governador '$target_gov' não disponível. Disponíveis: $available_govs"; return; }
    for cpu_path in /sys/devices/system/cpu/cpu[0-9]*; do
        gov_path="$cpu_path/cpufreq/scaling_governor"; cpu_id=${cpu_path##*cpu}; (( total_cores++ ))
        if [[ -w "$gov_path" ]]; then
            current_gov=$(<"$gov_path")
            if [[ "$current_gov" != "$target_gov" ]]; then if printf "%s" "$target_gov" > "$gov_path" 2>/dev/null; then (( changed++ )); else warn "Falha sysfs gov CPU $cpu_id."; fi fi
        elif command -v cpupower &>/dev/null; then
             current_gov=$(cpupower -c "$cpu_id" frequency-info -p 2>/dev/null | awk '/current policy/ {print $NF}') || current_gov=""
             if [[ "$current_gov" != "$target_gov" ]]; then if cpupower -c "$cpu_id" frequency-set -g "$target_gov" &>/dev/null; then (( changed++ )); else warn "Falha cpupower gov CPU $cpu_id."; fi fi
        fi
    done
    if (( changed > 0 )); then log "Governador CPU -> '$target_gov' ($changed/$total_cores)"; MODIFIED=1; else log "Governador CPU mantido: '$target_gov'"; fi
}

gpu_dpm() {
    local target_perf="$1" target_vram_clk="$2" target_pwr_limit="$3" target_boost_clk="$4"
    local gpu_dev_path="/sys/class/drm/card0/device" changed=0 current_value readable writeable file hwmon_path dpm_force_file target_dpm_state target_pwr_microwatts

    if [[ -v SAFE_LIMITS[VRAM_CLOCK] ]] && (( target_vram_clk > SAFE_LIMITS[VRAM_CLOCK] )); then
        warn "VRAM Clock $target_vram_clk MHz excede limite seguro (${SAFE_LIMITS[VRAM_CLOCK]}MHz). Ajustando."
        target_vram_clk=${SAFE_LIMITS[VRAM_CLOCK]}
    fi
     if [[ -v SAFE_LIMITS[BOOST_CLOCK] ]] && (( target_boost_clk > SAFE_LIMITS[BOOST_CLOCK] )); then
        warn "Boost Clock $target_boost_clk MHz excede limite seguro (${SAFE_LIMITS[BOOST_CLOCK]}MHz). Ajustando."
        target_boost_clk=${SAFE_LIMITS[BOOST_CLOCK]}
    fi
    if [[ -v SAFE_LIMITS[TDP] ]] && (( target_pwr_limit > SAFE_LIMITS[TDP] )); then
        warn "Power Limit $target_pwr_limit W excede limite seguro (${SAFE_LIMITS[TDP]}W). Ajustando."
        target_pwr_limit=${SAFE_LIMITS[TDP]}
    fi

    safe_gpu_write() {
        local value="$1" file="$2"; current_value=""; readable=0; writeable=0
        [[ -r "$file" ]] && readable=1 && current_value=$(<"$file")
        [[ -w "$file" ]] && writeable=1
        if [[ "$writeable" -eq 1 ]]; then
            if [[ "$readable" -eq 0 || "$current_value" != "$value" ]]; then
                 if printf "%s" "$value" >"$file" 2>/dev/null; then log "GPU: $file -> '$value'"; changed=1; else warn "GPU: Falha ao escrever '$value' em $file"; fi
            fi
        fi
    }

    if [[ ! -d "$gpu_dev_path" ]]; then return; fi

    dpm_force_file="$gpu_dev_path/power_dpm_force_performance_level"
    target_dpm_state="${target_perf//battery/low}"; target_dpm_state="${target_dpm_state//balanced/medium}"; target_dpm_state="${target_dpm_state//performance/high}"
    safe_gpu_write "$target_dpm_state" "$dpm_force_file"

    safe_gpu_write "$target_vram_clk" "$gpu_dev_path/pp_dpm_sclk"
    safe_gpu_write "$target_vram_clk" "$gpu_dev_path/gt_max_freq_mhz"

    safe_gpu_write "$target_boost_clk" "$gpu_dev_path/pp_dpm_mclk"
    safe_gpu_write "$target_boost_clk" "$gpu_dev_path/gt_boost_freq_mhz"

    target_pwr_microwatts=$((target_pwr_limit * 1000000))
    for hwmon_path in "$gpu_dev_path"/hwmon/hwmon*; do safe_gpu_write "$target_pwr_microwatts" "$hwmon_path/power1_cap"; done
    safe_gpu_write "$target_pwr_limit" "$gpu_dev_path/pp_power_profile_mode"

    if (( changed > 0 )); then log "Configurações GPU atualizadas (Verificar logs acima)"; MODIFIED=1; else log "Configurações GPU mantidas."; fi
}

zram_opt() {
    local target_pct="$1" target_alg="$2" target_streams="$3"
    local mem_total_kb current_zram_size=0 current_alg="" current_streams_count=0 change_needed=0 total_zram_size_mb=0 target_total_size_mb zram_dev_path dev_name dev_num size_bytes i added_dev zram_dev zram_sysfs size_per_stream_mb
    if ! modprobe zram &>/dev/null; then error "Falha ao carregar módulo zram."; return; fi
    mem_total_kb=$(awk '/MemTotal/{print $2}' /proc/meminfo)
    [[ -z "$mem_total_kb" ]] && { error "Não ler MemTotal"; return; }
    target_total_size_mb=$(( mem_total_kb * target_pct / 100 / 1024 ))
    [[ $target_total_size_mb -le 0 ]] && { log "ZRAM% ($target_pct%) -> 0MB. Desativando."; target_total_size_mb=0; }
    for zram_dev_path in /sys/block/zram*; do
       if [[ -d "$zram_dev_path" ]]; then
          dev_name=${zram_dev_path##*/}; dev_num=${dev_name#zram}
          (( current_streams_count++ ))
          current_alg=$(cat "$zram_dev_path/comp_algorithm" 2>/dev/null | awk '{print $1}' FS='[' | tr -d ']') || current_alg="?"
          size_bytes=$(cat "$zram_dev_path/disksize" 2>/dev/null) || size_bytes=0; current_zram_size=$(( current_zram_size + size_bytes ))
          if ! swapon -s | grep -q "/dev/${dev_name}"; then change_needed=1; break; fi
       fi
    done
    current_zram_size_mb=$(( current_zram_size / 1024 / 1024 ))
    if [[ "$current_streams_count" -ne "$target_streams" ]] || ([[ "$current_streams_count" -gt 0 ]] && [[ "$current_alg" != "$target_alg" ]]) || [[ "$current_zram_size_mb" -ne "$target_total_size_mb" ]] || [[ "$change_needed" -eq 1 ]]; then
       change_needed=1
       log "ZRAM atual ($current_streams_count,$current_alg,${current_zram_size_mb}MB) != alvo ($target_streams,$target_alg,${target_total_size_mb}MB). Reconfigurando."
    fi
    if [[ "$change_needed" -eq 1 ]]; then
        log "Desativando ZRAMs..."; swapoff /dev/zram* &>/dev/null || true
        i=0; while echo "$i" > /sys/class/zram-control/hot_remove 2>/dev/null; do ((i++)); done || modprobe -r zram && modprobe zram num_devices="$target_streams" || { error "Falha recarregar módulo zram."; return; }
        if (( target_total_size_mb > 0 )); then
             log "Configurando $target_streams ZRAM streams ($target_alg, ${target_total_size_mb}MB)..."
             size_per_stream_mb=$(( target_total_size_mb / target_streams )); [[ $size_per_stream_mb -le 0 ]] && size_per_stream_mb=1
             for i in $(seq 0 $((target_streams - 1))); do
                 added_dev=$(echo "$i" | tee /sys/class/zram-control/hot_add 2>/dev/null) || added_dev="$i"
                 if [[ ! -d "/sys/block/zram$i" ]]; then error "ZRAM device zram$i não existe."; continue; fi
                 zram_dev="zram$i"; zram_sysfs="/sys/block/$zram_dev"
                 echo "$target_alg" > "$zram_sysfs/comp_algorithm" || { warn "Falha alg zram$i"; continue; }
                 echo "${size_per_stream_mb}M" > "$zram_sysfs/disksize" || { warn "Falha size zram$i"; continue; }
                 mkswap "/dev/$zram_dev" &>/dev/null || { warn "Falha mkswap zram$i"; continue; }
                 swapon "/dev/$zram_dev" -p 5 &>/dev/null || { warn "Falha swapon zram$i"; continue; }
                 log "ZRAM /dev/$zram_dev ($target_alg, ${size_per_stream_mb}MB) ativado."
             done
        else log "ZRAM desativado (tamanho alvo 0MB)."; fi
        MODIFIED=1
    else log "Configuração ZRAM mantida."; fi
}

energy_opt() {
    local policy_key="$1" target_epb="$2" current_epb tlp_changed power_state power_profile cpu_gov gpu_mode
    current_epb=$(get_current_epb)
    if [[ "$current_epb" != "$target_epb" ]] && [[ "$current_epb" != "00" ]]; then
       if command -v wrmsr &>/dev/null; then
          if wrmsr -a 0x1b0 "$((16#$target_epb))" &>/dev/null; then log "EPB -> 0x$target_epb."; MODIFIED=1; else warn "Falha ao escrever EPB 0x$target_epb."; fi
       else warn "wrmsr não encontrado."; fi
    else log "EPB mantido: 0x$target_epb."; fi
    if command -v tlp &>/dev/null; then
        tlp_changed=0
        IFS=' ' read -r cpu_gov gpu_mode _ _ _ _ _ _ _ _ _ <<< "${HOLISTIC_POLICIES[$policy_key]:-"unknown unknown"}"
        power_state=$(get_power_source)
        if [[ "$power_state" == "1" ]]; then power_profile="AC"; else power_profile="BAT"; fi
        if tlp start >/dev/null; then log "TLP re-aplicado para estado $power_profile."; else warn "Falha ao executar tlp start."; fi
    fi
}

ajustar_swappiness() {
    local target_swappiness="$1" current_swappiness
    current_swappiness=$(get_current_swappiness)
    if [[ "$current_swappiness" != "$target_swappiness" ]] && [[ "$current_swappiness" != "-1" ]]; then
       if sysctl -w vm.swappiness="$target_swappiness" >/dev/null; then log "vm.swappiness -> $target_swappiness."; MODIFIED=1; else warn "Falha ajustar vm.swappiness."; fi
    else log "vm.swappiness mantido: $target_swappiness."; fi
}

main_loop() {
    log "Iniciando loop de monitoramento e otimização..."
    touch "$HISTORY_FILE" "${HISTORY_FILE}.stat"
    CURRENT_POLICY_KEY=$(cat "$STATUS_FILE" 2>/dev/null || echo "unknown")
    CURRENT_EMA=$(get_cpu_usage)

    while true; do
        local target_policy_key sleep_interval policy_values cpu_gov gpu_perf cores epb zram_pct zram_alg zram_str swappiness vram_clk pwr_limit boost_clk load_range sleep_range relative_load
        MODIFIED=0

        target_policy_key=$(determine_policy_key)

        if [[ "$CURRENT_POLICY_KEY" != "$target_policy_key" ]]; then
            log "Política alvo mudou para: $target_policy_key (Anterior: $CURRENT_POLICY_KEY). Aplicando alterações..."

            if [[ -v HOLISTIC_POLICIES["$target_policy_key"] ]]; then
                policy_values="${HOLISTIC_POLICIES[$target_policy_key]}"
                IFS=' ' read -r cpu_gov gpu_perf cores epb zram_pct zram_alg zram_str swappiness vram_clk pwr_limit boost_clk <<< "$policy_values"

                log "Aplicando Perfil ${target_policy_key}: CPU=$cpu_gov GPU=$gpu_perf ZRAM=$zram_pct%/$zram_alg/$zram_str Swp=$swappiness EPB=$epb VRAM=$vram_clk PWR=$pwr_limit BOOST=$boost_clk"

                governor_apply "$cpu_gov"
                gpu_dpm "$gpu_perf" "$vram_clk" "$pwr_limit" "$boost_clk"
                zram_opt "$zram_pct" "$zram_alg" "$zram_str"
                energy_opt "$target_policy_key" "$epb"
                ajustar_swappiness "$swappiness"

                if [[ "$MODIFIED" -eq 1 ]]; then
                    log "Configurações atualizadas para a política $target_policy_key."
                    CURRENT_POLICY_KEY="$target_policy_key"
                    echo "$CURRENT_POLICY_KEY" > "$STATUS_FILE"
                else
                    log "Nenhuma alteração necessária para a política $target_policy_key (parâmetros já conformes)."
                    CURRENT_POLICY_KEY="$target_policy_key"
                    echo "$CURRENT_POLICY_KEY" > "$STATUS_FILE"
                fi
            else
                warn "Chave de política '$target_policy_key' não encontrada na tabela HOLISTIC_POLICIES."
            fi
        else
            log "Política mantida: $CURRENT_POLICY_KEY (EMA CPU: $CURRENT_EMA%)."
        fi

        if (( CURRENT_EMA > HIGH_LOAD_THRESHOLD )); then
            sleep_interval=$MIN_SLEEP_INTERVAL
        elif (( CURRENT_EMA < LOW_LOAD_THRESHOLD )); then
             sleep_interval=$MAX_SLEEP_INTERVAL
        else
             load_range=$(( HIGH_LOAD_THRESHOLD - LOW_LOAD_THRESHOLD ))
             sleep_range=$(( MAX_SLEEP_INTERVAL - MIN_SLEEP_INTERVAL ))
             relative_load=$(( CURRENT_EMA - LOW_LOAD_THRESHOLD ))
             [[ $load_range -eq 0 ]] && load_range=1 # Avoid division by zero
             sleep_interval=$(( MAX_SLEEP_INTERVAL - (relative_load * sleep_range / load_range) ))
             (( sleep_interval < MIN_SLEEP_INTERVAL )) && sleep_interval=$MIN_SLEEP_INTERVAL
             (( sleep_interval > MAX_SLEEP_INTERVAL )) && sleep_interval=$MAX_SLEEP_INTERVAL
        fi

        log "Próxima verificação em ${sleep_interval}s."
        sleep "$sleep_interval"
    done
}

setup_system() {
    log "--- Iniciando Setup do Sistema ---"
    load_execution_status
    check_root
    check_dependencies

    mkdir -p /var/log /var/opt
    touch "$LOG_PATH" "$HISTORY_FILE" "${HISTORY_FILE}.stat" "$STATUS_FILE" "$VERIFICATION_LOG"
    chown root:root "$LOG_PATH" "$HISTORY_FILE" "${HISTORY_FILE}.stat" "$STATUS_FILE" "$VERIFICATION_LOG"
    chmod 640 "$LOG_PATH" "$HISTORY_FILE" "${HISTORY_FILE}.stat" "$STATUS_FILE" "$VERIFICATION_LOG"
    registrar_execucao "DIRS_LOG_STATE" "1"

    optimize_kernel_sched

    log "Instalando script em $SCRIPT_PATH..."
    if install -Dm 744 /dev/stdin "$SCRIPT_PATH" <<< "$(cat "$0")"; then
       registrar_execucao "SCRIPT_INSTALL" "1"
    else
       error "Falha ao instalar $SCRIPT_PATH"; registrar_execucao "SCRIPT_INSTALL" "0"; exit 1;
    fi

    log "Criando serviço systemd em $SERVICE_PATH..."
    cat > "$SERVICE_PATH" << EOF
[Unit]
Description=Serviço de Otimização Holística de Energia (energy_opt)
After=network.target thermald.service preload.service
Requires=thermald.service

[Service]
Type=simple
ExecStart=$SCRIPT_PATH loop
Restart=on-failure
RestartSec=10s
StandardOutput=append:$LOG_PATH
StandardError=append:$LOG_PATH
Environment=LANG=C.UTF-8

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 "$SERVICE_PATH"
    registrar_execucao "SYSTEMD_SERVICE_CREATE" "1"

    log "Criando timer systemd em $TIMER_PATH..."
    cat > "$TIMER_PATH" << EOF
[Unit]
Description=Timer para Otimização Holística de Energia (energy_opt)
Requires=energy_opt.service

[Timer]
Unit=energy_opt.service

[Install]
WantedBy=timers.target
EOF
    chmod 644 "$TIMER_PATH"
    registrar_execucao "SYSTEMD_TIMER_CREATE" "1"

    log "Recarregando, habilitando e iniciando o timer systemd..."
    systemctl daemon-reload
    if systemctl enable --now energy_opt.timer; then
       registrar_execucao "SYSTEMD_ENABLE_START" "1"
       log "Setup concluído. Serviço iniciado via systemd timer."
       log "Logs do loop: $LOG_PATH"
       log "Logs do setup: $VERIFICATION_LOG"
    else
       error "Falha ao habilitar/iniciar energy_opt.timer"; registrar_execucao "SYSTEMD_ENABLE_START" "0"; exit 1;
    fi
    systemctl enable energy_opt.service

    log "--- Setup Finalizado ---"
}

case "${1:-}" in
    install)
        setup_system
        ;;
    loop)
        main_loop
        ;;
    status)
         echo "--- Status Atual ---"
         echo "Log Principal: $LOG_PATH"
         echo "Log de Setup: $VERIFICATION_LOG"
         echo "Script: $SCRIPT_PATH"
         echo "Serviço: $SERVICE_PATH"
         echo "Timer: $TIMER_PATH"
         echo "Última Política Aplicada: $(cat "$STATUS_FILE" 2>/dev/null || echo "N/A")"
         echo "EMA CPU Atual (Suavizado): $CURRENT_EMA %"
         echo "--- Status Systemd ---"
         systemctl status energy_opt.timer energy_opt.service --no-pager
         echo "--- Últimas Linhas do Log Principal ---"
         tail -n 10 "$LOG_PATH" 2>/dev/null || echo "Log vazio ou não encontrado."
         echo "--- Log de Setup ---"
         cat "$VERIFICATION_LOG" 2>/dev/null || echo "Log vazio ou não encontrado."
        ;;
    *)
        echo "Uso: $0 [install|loop|status]"
        echo "  install: Instala o script e configura os serviços systemd."
        echo "  loop:    Executa o loop principal (usado pelo systemd)."
        echo "  status:  Mostra informações de status e logs."
        exit 1
        ;;
esac

exit 0
