# Função para verificar e aplicar o swappiness
apply_swappiness() {
    local swappiness="$1"
    local current_swappiness
    current_swappiness=$(sysctl vm.swappiness | awk '{print $3}')
    if [[ "$current_swappiness" != "$swappiness" ]]; then
        sudo sysctl vm.swappiness="$swappiness" > /dev/null
        echo "✔️ Swappiness atualizado para $swappiness"
    else
        echo "⚙️ Swappiness já está configurado como $swappiness"
    fi
}