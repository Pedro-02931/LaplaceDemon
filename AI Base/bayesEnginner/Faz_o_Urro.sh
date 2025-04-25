#!/bin/bash
faz_o_urro() {
    local cpu="$1"
    local -a history=()
    local sum=0 avg

    [[ -f "$HISTORY_FILE" ]] && mapfile -t history < "$HISTORY_FILE"
    history+=("$cpu")

    if (( ${#history[@]} > MAX_HISTORY )); then
        history=("${history[@]: -$MAX_HISTORY}")
    fi

    for n in "${history[@]}"; do
        sum=$((sum + n))
    done

    avg=$((sum / ${#history[@]}))
    printf "%s\n" "${history[@]}" > "$HISTORY_FILE"
    echo "$avg"
}