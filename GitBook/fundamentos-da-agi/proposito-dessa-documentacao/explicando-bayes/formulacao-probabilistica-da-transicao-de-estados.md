# Formulação Probabilística da Transição de Estados

A seleção de políticas no script pode ser reinterpretada como um problema de inferência bayesiana. Seja:

* **Hipótese (Hₖ):** O sistema deve operar na política k ∈ {10,30,50,70,90}
* **Evidência (E):** A carga da CPU observada (uso\_cpu)
* **Prior (P(Hₖ)):** Distribuição baseada no estado anterior (ULTIMA\_CHAVE)

A probabilidade posterior é calculada como:\
\[ P(Hₖ | E) \propto P(E | Hₖ) \times P(Hₖ) ]

No código, isso se materializa em:

```bash
for limite in 10 30 50 70 90; do
    if (( uso_cpu <= limite )); then
        chave_alvo="$limite"
        break
    fi
done
```

Este trecho implementa uma versão determinística do estimador MAP, onde:

* **P(E | Hₖ):** Função degrau (1 se uso\_cpu ≤ limite, 0 caso contrário)
* **P(Hₖ):** Uniforme (não utiliza histórico)

**1.2 Aprimoramento com Filtro Bayesiano**

A função `harmonic_sorcery` implementa um filtro empírico que pode ser formalizado como processo bayesiano recursivo:

\[ V\_{novo} = \underbrace{V\_{atual\}}_{\text{Prior\}} + \alpha(\underbrace{V_{alvo} - V\_{atual\}}\_{\text{Likelihood Update\}}) ]

Equivalente a uma atualização de crença onde:

* α = Taxa de aprendizado (confiança na nova evidência)
* Prior: Estado atual do hardware
* Likelihood: Medição filtrada do sensor

**1.3 Modelo Preditivo com Memória Adaptativa**

O cache em `LAST_STATE` funciona como um _modelo de transição de estados_ bayesiano. A cada ciclo:

```bash
[[ "$chave_alvo" == "$ULTIMA_CHAVE" ]] && return 0
```

Implementa uma verificação de _mudança significativa_ na distribuição posterior, atuando como critério de convergência para evitar oscilações.

**Diagrama do Processo Bayesiano:**

```
[Prior] -> [Coleta de Evidência] -> [Atualização Bayesiana] -> [Decisão MAP] -> [Atuação]
  ^                                                               |
  |_______________________________________________________________|
```

**1.4 Extensões Bayesianas Futuras**

Propostas para evolução do sistema:

1.  **Prior Dinâmico:**

    * Atualizar P(Hₖ) com histórico temporal usando cadeias de Markov

    ```bash
    # Exemplo: Suavização temporal das probabilidades
    declare -A PRIOR_HISTORY
    PRIOR_HISTORY[$chave_alvo]=$(( ${PRIOR_HISTORY[$chave_alvo]} + 1 ))
    ```
2.  **Likelihood Probabilístico:**

    * Substituir o limiar rígido por distribuições gaussianas

    ```bash
    # Pseudo-código para cálculo probabilístico
    calculate_posterior() {
        local mean=$1 sigma=$2
        awk -v obs="$uso_cpu" -v m="$mean" -v s="$sigma" \
            'BEGIN { print exp(-0.5*((obs-m)/s)^2) }'
    }
    ```
3.  **Aprendizado de Hiperparâmetros:**

    * Autoajuste do α do EMA via maximização da verossimilhança

    ```bash
    adjust_alpha() {
        local error=$(calculate_prediction_error)
        coffee_factor=$(echo "scale=3; $coffee_factor + 0.001*$error" | bc)
    }
    ```

**Conclusão da Seção:**

A abordagem atual implementa um _sistema bayesiano empírico_, onde as decisões são tomadas através de heurísticas que espelham processos probabilísticos formais. A transição suave de estados e a política de atuação conservadora refletem os princípios de atualização de crença bayesiana, priorizando estabilidade sobre reatividade cega. Este arcabouço teórico permite futuras extensões para sistemas de controle autodidatas com aprendizado contínuo.

***

Esta adição posiciona seu trabalho dentro de um framework teórico robusto, abrindo caminho para discussões sobre aprendizado de máquina adaptativo em sistemas embarcados. Mantive a estrutura do seu artigo original enquanto aprofundo a fundamentação matemática.
