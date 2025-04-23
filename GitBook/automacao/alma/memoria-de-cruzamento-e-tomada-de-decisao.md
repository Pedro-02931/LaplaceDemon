# Memoria de Cruzamento e Tomada de Decisão

A alma desse sistema reside na tabela `HOLISTIC_POLICIES`, um mapa pré-definido que conecta o estado atual da máquina a um conjunto completo de configurações otimizadas, funcionando como um cérebro reptiliano que já sabe a melhor resposta para certos estímulos sem precisar pensar muito, apenas reagir com base no que já foi mapeado como eficiente para aquela situação específica, essa abordagem bayesiana simplificada permite uma adaptação rápida e determinística.

> Ou seja, ao invés de ser simplesmente reativa entre, onde espera sobre-aquecer para tomar decisão, o objetivo é fazer um tunig inteligente, onde cada consfiguração é pré-mapeada e a maquina se ajusta com base naquela configuração.

A chave de acesso a essa tabela é uma concatenação inteligente de três fatores críticos: a média móvel exponencial (EMA) do uso da CPU representando a tendência de carga recente, um indicador binário se a temperatura ultrapassou um limite crítico e outro indicador se a máquina está na bateria ou na tomada, criando assim um código único que reflete uma fotografia multifacetada do estado operacional do sistema naquele instante.

> Aqui a configuração funciona maios ou menos seguindo o padrão de adaptação humano, e como exemplo, posso citar o resfriamento termico, onde ao invés do corpo esperar a hiportemia, ele simplemente contrai ou dilata a circulação sanguínea, assim garantindo um controle inteligente sobre a temperatura corporal

Do ponto de vista eletrônico, isso se traduz em ler sensores e estados que o kernel Linux gentilmente expõe no `/sys` e `/proc`, como os contadores de tempo de CPU em `/proc/stat` para calcular o uso, os sensores térmicos em `/sys/class/thermal` para a temperatura e o status da fonte em `/sys/class/power_supply`, esses valores crus, que refletem diretamente a atividade dos transistores na CPU, a dissipação de calor e o fluxo de energia, são processados e combinados pela função `determine_policy_key` para gerar aquela chave única.&#x20;

A beleza está em não precisar de uma IA complexa ou machine learning pesado para decidir, mas sim usar esses indicadores físicos diretos para escolher uma receita de bolo já testada e aprovada na `HOLISTIC_POLICIES`, garantindo uma resposta previsível e eficiente baseada nas condições reais do hardware sem sobrecarregar o próprio sistema com cálculos complexos de otimização.

> [O software de teste aqui](https://github.com/Pedro-02931/LaplaceDemon/blob/prototypes/Rede/autoconf.sh) já está funcinou aqui nesse repositório, onde fiz com base em protencia de sinal em roteador, extendendo a distancia util de trabalho sem perda de pacotes.

{% code overflow="wrap" %}
```bash
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
```
{% endcode %}

***
