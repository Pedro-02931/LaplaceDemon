#!/bin/bash
faz_o_urro() {
    local new_val="$1"
    local -a history=()
    local sum=0 avg

    [[ -f "$HISTORY_FILE" ]] && mapfile -t history < "$HISTORY_FILE"
    history+=("$new_val")

    if (( ${#history[@]} > MAX_HISTORY )); then
        history=("${history[@]: -$MAX_HISTORY}")
    fi

    for val in "${history[@]}"; do
        sum=$((sum + val))
    done

    avg=$((sum / ${#history[@]}))
    printf "%s\n" "${history[@]}" > "$HISTORY_FILE"
    echo "$avg"
}