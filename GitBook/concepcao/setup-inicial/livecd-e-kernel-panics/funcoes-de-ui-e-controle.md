# Funções de UI e Controle

### O que foi feito:

Aqui, decidi implementar uma tecnica de renderização para conforto do usuário, onde a função `d_l` garante que tudo seja escrito em função da capacidade de renderiação humana média (valor entre 100ms e 300 ms). Ela coleta cada letro cuspida da váriavel, e espera um tempo para ser renderizada, assim, facilitando a absoção do que é reproduzido.

A `confirmar_execucao` é auto-explicativa, enquanto `ja_executado` e `marcar_como_executado` usam o `CONTROL_FILE` para saber se uma etapa crucial já foi feita, impedindo repetições desnecessárias e potencialmente perigosas, como tentar criar partições em um disco já particionado ou apenas evitar sobreescritas desnecessária.

{% code overflow="wrap" %}
```bash
d_l() {
    local t="$1"
    for ((i=0; i<${#t}; i++)); do
        echo -n "${t:i:1}"
        sleep 0.02
    done
    echo
}

confirmar_execucao() {
    local acao="$1"
    d_l "$acao"
    read -p "Deseja aplicar esta configuração? [s/N]: " resp
    [[ "$resp" =~ ^[sS]$ ]]
}

ja_executado() {
    grep -qFx "$1" "$CONTROL_FILE" 2>/dev/null
}

marcar_como_executado() {
    echo "$1" >> "$CONTROL_FILE"
}


```
{% endcode %}
