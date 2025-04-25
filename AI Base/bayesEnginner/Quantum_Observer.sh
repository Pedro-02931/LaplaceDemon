determine_policy_key() {
    local cpu_usage temp power_source temp_critical_flag key fallback_key usage_key

    cpu_usage=$(get_cpu_usage)
    temp=$(get_cpu_temp)
    power_source=$(get_power_source)

    faz_o_urro "$cpu_usage"  # Atualiza a EMA

    (( temp >= CRITICAL_TEMP_THRESHOLD )) && temp_critical_flag=1 || temp_critical_flag=0

    printf -v usage_key "%03d" "$CURRENT_EMA"  # Formata EMA para 3 dígitos
    key="${usage_key}${temp_critical_flag}${power_source}"  # Monta a chave principal

    # Verifica se a chave exata existe na tabela
    if [[ -v HOLISTIC_POLICIES["$key"] ]]; then
        echo "$key"
        return
    fi

    # Fallback baseado em graduação fixa
    fallback_key=""

    if [[ "$temp_critical_flag" -eq 1 ]]; then
        if [[ "$power_source" -eq 0 ]]; then
            # Bateria + Temp crítica
            if (( CURRENT_EMA < 20 )); then
                fallback_key="00010"
            elif (( CURRENT_EMA < 40 )); then
                fallback_key="00510"
            elif (( CURRENT_EMA < 60 )); then
                fallback_key="01010"
            elif (( CURRENT_EMA < 80 )); then
                fallback_key="02010"
            else
                fallback_key="03010"  # Máximo definido para bateria + temp crítica
            fi
        else
            # Tomada + Temp crítica
            if (( CURRENT_EMA < 20 )); then
                fallback_key="00011"
            elif (( CURRENT_EMA < 40 )); then
                fallback_key="00511"
            elif (( CURRENT_EMA < 60 )); then
                fallback_key="01011"
            elif (( CURRENT_EMA < 80 )); then
                fallback_key="02011"
            else
                fallback_key="03011"  # Máximo definido para tomada + temp crítica
            fi
        fi
    else
        if [[ "$power_source" -eq 0 ]]; then
            # Bateria + Temp ok
            if (( CURRENT_EMA < 20 )); then
                fallback_key="00000"
            elif (( CURRENT_EMA < 40 )); then
                fallback_key="00500"
            elif (( CURRENT_EMA < 60 )); then
                fallback_key="01000"
            elif (( CURRENT_EMA < 80 )); then
                fallback_key="02000"
            else
                fallback_key="03000"  # Máximo definido para bateria + temp ok
            fi
        else
            # Tomada + Temp ok
            if (( CURRENT_EMA < 20 )); then
                fallback_key="00001"
            elif (( CURRENT_EMA < 40 )); then
                fallback_key="00501"
            elif (( CURRENT_EMA < 60 )); then
                fallback_key="01001"
            elif (( CURRENT_EMA < 80 )); then
                fallback_key="02001"
            else
                fallback_key="03001"  # Máximo definido para tomada + temp ok
            fi
        fi
    fi

    if [[ -v HOLISTIC_POLICIES["$fallback_key"] ]]; then
        warn "Chave exata '$key' não encontrada. Usando fallback mapeado: '$fallback_key'"
        echo "$fallback_key"
    else
        warn "Nenhuma política encontrada para o estado atual (Chave: $key). Mantendo estado anterior."
        echo "$CURRENT_POLICY_KEY"
    fi
}