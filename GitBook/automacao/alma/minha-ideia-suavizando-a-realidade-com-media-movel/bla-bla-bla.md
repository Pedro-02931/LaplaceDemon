# Blá Blá Blá

### 🔹 `local -a history=()`

* `local`: Cria uma **variável local à função** (não vaza pro resto do script).
* `-a`: Declara a variável como **array** (lista de valores).
* `history=()`: Inicializa o array vazio.

> - A declaração `local -a history=()` está criando uma variável chamada `history` no escopo local da função, ou seja, ela só existe dentro da função onde foi definida. O modificador `-a` informa ao interpretador que essa variável é um array.&#x20;
> - Arrays em Bash são estruturas que armazenam múltiplos valores em índices numerados, e são úteis quando você precisa guardar uma sequência de valores, como um histórico de leituras de uso da CPU.

***

### 🔹 `local count=0 i=0 start_index`

Declara três variáveis locais:

* `count`: contador do número de elementos no array.
* `i`: índice (geralmente usado em loops).
* `start_index`: posição de corte no histórico, se ele for maior que o máximo permitido.

> - Nessa linha, você está declarando três variáveis locais ao mesmo tempo:
>   * `count` será usada para armazenar o número de elementos atualmente no array `history`.&#x20;
>   * A variável `i`, embora declarada aqui, pode ser usada para laços ou iterações posteriores.&#x20;
>   * Já `start_index` será utilizada caso seja necessário cortar os elementos mais antigos do histórico, mantendo apenas os mais recentes com base em um limite máximo de histórico (`MAX_HISTORY`).&#x20;

***

### 🔹 `[[ -f "$HISTORY_FILE" ]] && mapfile -t history < "$HISTORY_FILE"`

Essa linha lê o histórico salvo em um arquivo, **se ele existir**.

* `[[ -f "$HISTORY_FILE" ]]`: verifica se o arquivo existe e é um arquivo comum.
* `&&`: só executa o comando seguinte se o anterior for verdadeiro.
* `mapfile -t history < "$HISTORY_FILE"`:
  * Lê cada linha do arquivo e joga como um item do array `history`.
  * `-t` remove os  no final das linhas.

> - Essa linha verifica se existe um arquivo chamado `HISTORY_FILE`, que é presumivelmente um caminho para onde o histórico das métricas anteriores está sendo armazenado e o operador `[[ -f ... ]]` é uma verificação de existência de arquivo regular (não diretório, não dispositivo) e se esse arquivo existir, então `mapfile -t history < "$HISTORY_FILE"` será executado.
> - O comando `mapfile` lê o conteúdo de um arquivo linha por linha e armazena cada linha como um elemento de um array e assim o modificador `-t` remove os caracteres de nova linha () do final de cada linha lida.&#x20;
> - Com isso, o array `history` conterá os valores lidos do arquivo, prontos para serem processados ou atualizados. Esse padrão é útil para restaurar um estado anterior do script.

***

### 🔹 `count=${#history[@]}`

Essa é a forma de contar **quantos elementos** tem no array `history`.

* `${#array[@]}`: retorna o número de elementos.

> A expressão `${#history[@]}` retorna o número total de elementos armazenados no array `history`,  fundamental para decidir se o histórico está dentro do tamanho máximo permitido ou se já é necessário truncá-lo para evitar crescimento infinito.

***

### 🔹 Bloco de truncamento do histórico:

```bash
if (( count > MAX_HISTORY )); then
  start_index=$((count - MAX_HISTORY))
  history=("${history[@]:$start_index}")
  count=$MAX_HISTORY
fi
```

#### Explicação:

* Se o histórico ficou **maior que o permitido** (`MAX_HISTORY`):
  1.  Calcula onde começa o novo histórico:

      ```bash
      start_index = total - máximo permitido
      ```
  2.  Corta o array só do `start_index` até o fim:

      ```bash
      history=("${history[@]:$start_index}")
      ```

      Isso usa **slicing de array** do Bash (`array[@]:start`).
  3. Atualiza o `count` pra refletir que agora ele tem só `MAX_HISTORY` itens.

> - Por exemplo, se `count` for 10 e `MAX_HISTORY` for 5, o novo `start_index` será 5, e a nova lista conterá apenas os elementos do índice 5 ao final.&#x20;
> - O array original é substituído por essa nova versão truncada e o contador `count` é atualizado para refletir o novo tamanho.&#x20;
> - Isso garante que você sempre trabalhe com uma janela deslizante de valores recentes, o que é coerente com o uso de médias móveis.

***

### 🔹 AWK:

```bash
CURRENT_EMA=$(awk -v cv="$current_metric" -v a="$EMA_ALPHA" -v pe="$CURRENT_EMA" \
'BEGIN { printf "%.0f", a * cv + (1 - a) * pe }')
```

**`awk`**

Ferramenta de linha de comando para **processamento de texto**, mas também faz **cálculos matemáticos** com precisão de ponto flutuante.

> `awk` é uma linguagem de processamento de texto mas fiz uma gambiarra para usa-la como uma calculadora de precisão flutuante, pois o Bash tradicional não lida bem com números com ponto flutuante em expressões aritméticas nativas.

**`-v nome=valor`**

Passa variáveis do Bash para dentro do AWK. No caso:

| Bash var          | AWK var | Significado          |
| ----------------- | ------- | -------------------- |
| `$current_metric` | `cv`    | valor atual medido   |
| `$EMA_ALPHA`      | `a`     | peso do valor novo   |
| `$CURRENT_EMA`    | `pe`    | última EMA calculada |

> A opção `-v` é usada para passar variáveis do ambiente do Bash para dentro do script `awk` e são passadas três variáveis:&#x20;
>
> * `cv` (current value), que representa a última métrica lida;&#x20;
> * `a`, que é o alpha, ou peso do valor novo na fórmula da média exponencial;&#x20;
> * `pe`, que é o valor da EMA anterior, armazenado previamente em `CURRENT_EMA`.

***

**`BEGIN { ... }`**

O bloco `BEGIN` é executado **antes** de o AWK processar qualquer linha de input. Como você **não está lendo arquivos ou linhas**, você só quer executar o cálculo matemático ~~GAMBIARRA~~.

***

**`printf "%.0f", a * cv + (1 - a) * pe`**

* `a * cv + (1 - a) * pe`: aplica a fórmula da EMA.
* `printf "%.0f"`: formata a saída como número inteiro (`.0f` = sem casas decimais).
  * Ex: 63.7 → 64

> - Essa é uma fórmula clássica usada em estatísticas e controle de sistemas para suavizar dados, dando mais peso a valores recentes.&#x20;
> - O `printf "%.0f"` formata a saída como um número inteiro (zero casas decimais), o que é útil se o seu sistema espera um número inteiro como métrica final.&#x20;
> - A saída do `awk` é então capturada pelo `$(...)` e atribuída de volta à variável `CURRENT_EMA`.

***

***
