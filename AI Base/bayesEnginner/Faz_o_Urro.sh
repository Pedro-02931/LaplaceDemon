#!/bin/bash
faz_o_urro() {
    local current_metric="$1"
    local -a history=()
    local count=0 i=0 start_index
    # Por que o start começa vazio? ele é slvo como materia cinzenta no sistema?

    [[ -f "$HISTORY_FILE" ]] && mapfile -t history < "$HISTORY_FILE"
    # Para que serve esse -f? que porra é mapfile? e essa flag -t?

    history+=("$current_metric")
    count=${#history[@]}
    # O que significa esse '{#' ?

    if (( count > MAX_HISTORY )); then
        start_index=$((count - MAX_HISTORY))
        history=("${history[@]:$start_index}")
        count=$MAX_HISTORY
    fi

    CURRENT_EMA=$(awk -v cv="$current_metric" -v a="$EMA_ALPHA" -v pe="$CURRENT_EMA" \
        'BEGIN {
                printf "%.0f",
                (a * cv) + ((1 - a) * pe)
            }
        }'
    printf "%s\n" "${history[@]}" > "$HISTORY_FILE"

}