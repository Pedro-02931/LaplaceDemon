# Minha ideia: Suavizando a Realidade com Média Móvel

A função `faz_o_urro` é crucial para evitar que o sistema tenha reações espasmódicas a cada pequena flutuação no uso da CPU, ela implementa uma Média Móvel Exponencial (EMA), que é uma forma inteligente de calcular uma média que dá mais peso aos dados mais recentes sem descartar completamente o histórico passado, agindo como um filtro passa-baixa que suaviza os picos e vales momentâneos.&#x20;

A lógica é simples: em vez de confiar cegamente no último valor de uso de CPU medido, que pode ser um pico isolado causado por abrir um programa ou uma queda súbita por um processo ter terminado, a EMA nos dá um valor que representa melhor a _tendência_ de carga do sistema, é como olhar para a maré subindo ou descendo em vez de se distrair com cada onda individual que quebra na praia, permitindo decisões mais ponderadas e estáveis.

> Usei essa tecnica para evitar os falsos positivos que quebram a expectativa, onde ao abrir um app pode haver um consumo gigantesto de CPU para abrir, mas se estabiliza aopos três medições, mesmo não tendo mudado de uso.
>
> Esse flip-flop pode ser desgastante para o computador, e essa suavização evita um sistema reativo que sobreescreve configurações desnecessária.

Eletronicamente falando, o uso da CPU medido em `/proc/stat` reflete a atividade quase instantânea dos ciclos de clock sendo consumidos pelos processos, essa atividade pode ser extremamente volátil, com transições de quase 0% para 100% e vice-versa em milissegundos dependendo do que o sistema operacional está escalonando.&#x20;

A `faz_o_urro`, ao aplicar a EMA sobre essas leituras brutas, transforma esse sinal ruidoso e cheio de transientes em um indicador mais estável do nível de demanda real sobre o processador, esse valor suavizado (`CURRENT_EMA`) é então usado para construir a chave da `HOLISTIC_POLICIES`, garantindo que as mudanças de perfil de energia só ocorram quando há uma mudança sustentada na carga, e não por causa de soluços momentâneos na atividade eletrônica do chip, mimetizando um sistema com inércia térmica ou elétrica que não reage a cada faísca.

> O objetivo é a garantia da inercia temporal nas expectativas bayesiana, evitando uma reação desnecessária a cada mudança, voltando mais na estabilidade inercial do que uma adaptação caótica.

{% code overflow="wrap" %}
```bash
readonly HISTORY_FILE="/var/opt/vemCaPutinha.harmonic.CPU_USAGE.state"
readonly MAX_HISTORY=15
readonly EMA_ALPHA=0.3
declare CURRENT_EMA=0 # Inicializa a EMA

faz_o_urro() {
    local current_metric="$1" # Recebe a métrica atual (uso de CPU)
    local -a history=()
    local count=0 i=0 start_index

    # Carrega o histórico do arquivo, se existir
    [[ -f "$HISTORY_FILE" ]] && mapfile -t history < "$HISTORY_FILE"

    # Adiciona a métrica atual ao histórico
    history+=("$current_metric")
    count=${#history[@]}

    # Mantém o histórico com no máximo MAX_HISTORY itens
    if (( count > MAX_HISTORY )); then
        start_index=$((count - MAX_HISTORY))
        history=("${history[@]:$start_index}") # Remove os mais antigos
        count=$MAX_HISTORY
    fi

    # Calcula a nova EMA (Média Móvel Exponencial)
    # EMA_nova = alpha * valor_atual + (1 - alpha) * EMA_anterior
    CURRENT_EMA=$(awk -v cv="$current_metric" -v a="$EMA_ALPHA" -v pe="$CURRENT_EMA" 'BEGIN {printf "%.0f", a * cv + (1 - a) * pe}')

    # Salva o histórico atualizado no arquivo
    printf "%s\n" "${history[@]}" > "$HISTORY_FILE"
}
```
{% endcode %}



***
