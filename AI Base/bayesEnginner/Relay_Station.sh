#!/bin/bash

load_intel_specs() {
    #TDB em Watts (ex: 15W)
    readonly MAX_TDP=$(cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_max_power_uw 2> /dev/null | awk '{print $1/1000000}') || 15 # Default TDP value -> Teste retornou 15 W executando direto do terminal

    # Frequência máxima da GPU em MHz ( Fallback baseada no UHD Graphics 620 )
    readonly MAX_GPU_CLOCK=$(cat /sys/class/drm/card0/gt_max_freq_mhz 2> /dev/null || echo 1000) # Default GPU clock value -> Teste retornou 1000 MHz executando direto do terminal e dado que é integrada, preciso só analisar ela
    readonly MIN_GPU_CLOCK=$(cat /sys/class/drm/card0/gt_min_freq_mhz 2> /dev/null || echo 300) # Default GPU clock value -> Teste retornou 300 MHz executando direto do terminal e dado que é integrada, preciso só analisar ela

    readonly CORES_TOTAL=$(nproc --all 2> /dev/null || echo 4) # Total de núcleos lógicos -> Teste retornou 4 executando direto do terminal
}

get_cpu_usage() {
    local usage avg_idle current_idle diff_idle
    #Que porra cada coisa essa merda quer dizer? no finall forma-se uma equaçãoa? pode me mostrar o calculo e exlicar cada simbolo?
    local last_total current_total diff_total last_usage cpu_line
    # Explique esses calculos e o modelo matematico também
    local stat_hist_file="%{HISTORY_FILE}.stat"
    # Pode explicar melhor isso?

    cpu_line=$(grep -E '^cpu ' /proc/stat)
<< EOF
# Ele cuspiu isso, pode validar? e que porra cada merda quer dizer?
´
grep '^cpu ' /proc/stat
cpu  471485 17 133012 2252257 19081 51310 4337 0 0 0
´
EOF

    read -r _ last_user last_nice last_system last_idle last_iowait last_irq last_softirq _ _ < <(grep '^cpu ' "$stat_hist_file" 2> /dev/null || echo "cpu 0 0 0 0 0 0 0 0 0 0")
    read -r _ current_user current_nice current_system current_idle current_iowait current_irq current_softirq _ _ < <(echo "$cpu_line")
    # Explique cada simbolo, nomencalturra tecnica e que porra quer dizes "_"? e que merda ele cospe no cpu line e cpu 0 0 0 0 0 0 0 0 0 0?

    echo "$cpu_line" > "$stat_hist_file"

    last_total=$((last_user + last_nice + last_system + last_idle + last_iowait + last_irq + last_softirq))
    # Quero que crie o modelo matematico e explique cada simbolo
    current_total=$((current_user + current_nice + current_system + current_idle + current_iowait + current_irq + current_softirq))
    # Relacione a anterior com essa com um unico model

    diff_idle=$((current_idle - last_idle))
    diff_total=$((current_total - last_total))
    # Por que fazer diff?

    if ((diff_total > 0)); then
        usage=$(( (1000 * (diff_total - diff_idle) / diff_total + 5) / 10 ))
    else
        usage=0
    fi

    echo "$usage"

}

<< EOF
Que porra quer dizer, explique funcionamento a nivel eletrônico e lógico e os acronimos:
- TDP
- Que porra tem relação com o what e que merda de calculo é esse e que arquibo isso significa. ele copia de todas as CPUs, tanto nucleos reais e virtuais? preciso de um estado geral de tudo. Como ele converte em Watts? 
- /sys/class
- /powercap
- /intel-rapl
- esse ':'
- 0/constraint_0_max_power_uw
- Por que e para que server esse print $1/1000000?