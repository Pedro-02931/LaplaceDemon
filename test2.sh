#!/bin/bash

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

# Loop para testar a função repetidamente
while true; do
    power_source=$(get_power_source)
    if [[ "$power_source" == "1" ]]; then
        echo "Fonte de energia externa conectada."
    else
        echo "Funcionando apenas com a bateria."
    fi
    sleep 1 # Aguarda 1 segundo antes de repetir
done
