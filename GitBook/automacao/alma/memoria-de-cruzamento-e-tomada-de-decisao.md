# Memoria de Cruzamento e Tomada de Decisão

```
declare -A HOLISTIC_POLICIES=(
    ["01000"]="powersave      battery     1       0A   10     zstd        1        15          350          25           10" # Baixo uso, Temp OK, Bateria
    ["03000"]="powersave      battery     3       0A   20     lz4         2        25          450          35           14" # Uso moderado-baixo, Temp OK, Bateria
    ["00010"]="powersave      battery     0       0F   5      zstd        1        10          300          20            8" # Uso baixo, Temp ALTA, Bateria -> Foco em resfriar
    ["01001"]="ondemand       balanced    5       06   30     zstd        3        35          550          45           18" # Baixo uso, Temp OK, AC
    ["05001"]="conservative   balanced    6       06   35     lz4         4        40          600          50           20" # Uso médio, Temp OK, AC
    ["08001"]="performance    performance 9       02   50     lz4         5        55          750          65           26" # Uso alto, Temp OK, AC
    ["10001"]="performance    performance 11      00   60     zstd        6        65          900          80           30" # Uso muito alto, Temp OK, AC -> Full power
    ["00011"]="conservative   balanced    4       0A   25     lz4         2        30          500          40           16" # Uso baixo, Temp ALTA, AC -> Prioriza resfriar na tomada
)
# ... (outras variáveis e funções) ...
determine_policy_key() {
    local cpu_usage temp power_source temp_critical_flag key fallback_key best_match_key key_usage diff min_diff k
    cpu_usage=$(get_cpu_usage)
    temp=$(get_cpu_temp)
    power_source=$(get_power_source)

    faz_o_urro "$cpu_usage" # Atualiza a média móvel (EMA)

    (( temp >= CRITICAL_TEMP_THRESHOLD )) && temp_critical_flag=1 || temp_critical_flag=0

    local usage_key
    printf -v usage_key "%03d" "$CURRENT_EMA" # Formata EMA para 3 dígitos

    key="${usage_key}${temp_critical_flag}${power_source}" # Monta a chave: EMA(000-100) + TempFlag(0/1) + Power(0/1)

    # Verifica se a chave exata existe na tabela
    if [[ -v HOLISTIC_POLICIES["$key"] ]]; then
        echo "$key"
        return
    fi

    # Lógica de fallback (procura a chave mais próxima se a exata não existir)
    fallback_key=""
    if [[ "$temp_critical_flag" -eq 1 ]]; then # Se temp crítica, procura chaves com flag de temp crítica
        for k in "${!HOLISTIC_POLICIES[@]}"; do
            if [[ "${k:3:1}" == "1" ]] && [[ "${k:4:1}" == "$power_source" ]]; then
                fallback_key="$k"; break
            fi
        done
    else # Se temp OK, procura a chave com EMA mais próxima na mesma condição de energia
        best_match_key="" min_diff=999
        for k in "${!HOLISTIC_POLICIES[@]}"; do
            if [[ "${k:3:1}" == "0" ]] && [[ "${k:4:1}" == "$power_source" ]]; then
                key_usage=$((10#${k:0:3})) # Pega o uso da chave K
                diff=$(( CURRENT_EMA - key_usage )) # Calcula diferença
                (( diff < 0 )) && diff=$(( -diff )) # Valor absoluto da diferença
                if (( diff < min_diff )); then # Se a diferença for menor que a mínima encontrada até agora
                    min_diff=$diff
                    best_match_key="$k" # Atualiza a melhor chave encontrada
                fi
            fi
        done
        fallback_key="$best_match_key"
    fi

    if [[ -n "$fallback_key" ]]; then
        warn "Chave exata '$key' não encontrada. Usando fallback mais próximo: '$fallback_key'"
        echo "$fallback_key"
    else
        warn "Nenhuma política encontrada para o estado atual (Chave: $key). Mantendo estado anterior."
        echo "$CURRENT_POLICY_KEY" # Retorna a chave atual se nenhum fallback for encontrado
    fi
}

```

**Explicação a nível lógico e eletrônico**

A alma desse sistema reside na tabela `HOLISTIC_POLICIES`, um mapa pré-definido que conecta o estado atual da máquina a um conjunto completo de configurações otimizadas, funcionando como um cérebro reptiliano que já sabe a melhor resposta para certos estímulos sem precisar pensar muito, apenas reagir com base no que já foi mapeado como eficiente para aquela situação específica, essa abordagem bayesiana simplificada permite uma adaptação rápida e determinística. A chave de acesso a essa tabela é uma concatenação inteligente de três fatores críticos: a média móvel exponencial (EMA) do uso da CPU representando a tendência de carga recente, um indicador binário se a temperatura ultrapassou um limite crítico e outro indicador se a máquina está na bateria ou na tomada, criando assim um código único que reflete uma fotografia multifacetada do estado operacional do sistema naquele instante.

Do ponto de vista eletrônico, isso se traduz em ler sensores e estados que o kernel Linux gentilmente expõe no `/sys` e `/proc`, como os contadores de tempo de CPU em `/proc/stat` para calcular o uso, os sensores térmicos em `/sys/class/thermal` para a temperatura e o status da fonte em `/sys/class/power_supply`, esses valores crus, que refletem diretamente a atividade dos transistores na CPU, a dissipação de calor e o fluxo de energia, são processados e combinados pela função `determine_policy_key` para gerar aquela chave única. A beleza está em não precisar de uma IA complexa ou machine learning pesado para decidir, mas sim usar esses indicadores físicos diretos para escolher uma receita de bolo já testada e aprovada na `HOLISTIC_POLICIES`, garantindo uma resposta previsível e eficiente baseada nas condições reais do hardware sem sobrecarregar o próprio sistema com cálculos complexos de otimização.

## Ganhos em relação entre o método tradicional e o meu

| **Característica**    | **Método Tradicional (Ex: Kernel Default, TLP Simples)**                                | **Meu Método (Holístico Adaptativo)**                                                               |
| --------------------- | --------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **Tomada de Decisão** | Geralmente reativa, baseada em 1 ou 2 fatores (uso CPU instantâneo, AC/Bateria).        | Proativa e holística, baseada em múltiplos fatores combinados (tendência de uso CPU, temp, AC/Bat). |
| **Configuração**      | Aplica políticas genéricas (powersave, performance) ou ajustes isolados por ferramenta. | Aplica um conjunto _completo_ e _integrado_ de configurações (CPU, GPU, ZRAM, Swappiness, EPB).     |
| **Complexidade**      | Baixa complexidade intrínseca, mas pode exigir múltiplas ferramentas e configs.         | Média complexidade no script, mas centraliza o controle e simplifica a gestão geral.                |
| **Adaptação**         | Geralmente mais lenta ou baseada em limiares simples, pode oscilar muito.               | Rápida seleção de estados pré-definidos e estáveis, com suavização de entrada (EMA).                |
| **Granularidade**     | Menos granular, com poucos estados (AC vs Bateria, talvez ondemand vs powersave).       | Alta granularidade através das chaves combinadas, permitindo estados intermediários finos.          |
| **Filosofia**         | Reagir ao uso atual, focar em extremos (máxima economia ou máximo desempenho).          | Antecipar a necessidade baseado na tendência, otimizar para o _cenário_ atual, buscando eficiência. |
| **Estabilidade**      | Pode causar mais flutuações (ex: ondemand subindo e descendo rápido).                   | Busca estados mais estáveis, a mudança é uma transição para um novo platô otimizado.                |

***
