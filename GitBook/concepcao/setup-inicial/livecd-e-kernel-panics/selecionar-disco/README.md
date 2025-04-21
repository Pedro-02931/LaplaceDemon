# Selecionar Disco

Esta função é crucial para garantir que a formatação ocorra no lugar certo, evitando a catástrofe de apagar o disco errado, em que o comando `lsblk -dpno NAME,SIZE,MODEL` lista todos os dispositivos de bloco (discos, partições) de forma clara, mostrando o nome completo do dispositivo (`/dev/sda`, `/dev/nvme0n1`), tamanho e modelo, facilitando a identificação visual.&#x20;

O `nl -w2 -s'. '` adiciona um número sequencial a cada linha, tornando a seleção pelo usuário mais simples e menos propensa a erros de digitação, onde ao invés do ~~imbecil~~ usuario digitar tudo, basta teclar a opção.

O comando `read -p "..." idx` pausa o script e pede ao usuário para digitar o número correspondente ao disco desejado, essa interação é vital para a segurança, e sendo complementado com o `sed -n "${idx}p"`,  extrai apenas o nome do disco (`/dev/sdX`) referente ao número escolhido e armazena na variável `DISK`.&#x20;

A verificação `if [[ -z "$DISK" ]]` confere se a variável `DISK` ficou vazia (o que aconteceria se o usuário digitasse um número inválido ou apenas pressionasse Enter), e caso esteja vazia, exibe uma mensagem de erro, registra no log e encerra o script (`exit 1`), atuando como uma última verificação de segurança para impedir que o script continue sem um alvo válido.

{% code overflow="wrap" %}
```bash
selecionar_disco() {
    d_l "Detectando discos disponíveis..."
    lsblk -dpno NAME,SIZE,MODEL | nl -w2 -s'. '
    echo
    read -p "Escolha o número do disco para formatar: " idx
    DISK=$(lsblk -dpno NAME | sed -n "${idx}p")
    if [[ -z "$DISK" ]]; then
        echo "Disco inválido!" | tee -a "$LOG_FILE" >&2
        exit 1
    fi
    d_l "Você escolheu o disco $DISK"
}
```
{% endcode %}
