# Blá Blá Blá

### 🔹 M**édia Móvel Exponencial (EMA)**

A **EMA (Exponential Moving Average)** é uma forma de suavizar dados de séries temporais, dando **mais peso às observações mais recentes**.

No caso, aqui ela está sendo aplicada ao **uso da CPU**, então:

* Se a CPU teve picos de uso recentes, mesmo que tenha caído um pouco agora, a EMA ainda "lembra" dessa atividade.
* Ajuda a capturar **tendência recente de carga** e não só o instante atual.

Decidi usar aqui para evitar os falsos positivos que podem enganar o sistema, onde a variação pode levar o equivoco, por exemplo, ao abrir um app, há um pico de consumo, ao fechar, há um vale.

> $$\text{EMA}_{\text{atual}} = \alpha \cdot \text{Valor atual} + (1 - \alpha) \cdot \text{EMA anterior}$$
>
> #### Onde:
>
> \- \`α\` é um valor entre 0 e 1 que determina \*\*o peso do valor novo\*\*. Ex: \`0.3\` dá 30% de peso ao novo valor, sendo pré definido e é uma constante de sensibilidade (recomendado entre 0.1 e 0.3)
>
> \- \`Valor atual\` é a métrica que você acabou de medir (ex: 80% de CPU).
>
> \- \`EMA anterior\` é o valor suavizado acumulado (o que você já tinha antes).



***

### 🔹 Fatores de Chaves

A **chave** que acessa a `HOLISTIC_POLICIES` é um número composto por:

```
[key] = [EMA-level][temp_critical_flag][power_status]
```

Exemplo: `01000`

* **"01"** = nível da EMA (baixo uso de CPU)
* **"0"** = temperatura **não** crítica
* **"0"** = está **na bateria**

Outro: `08001`

* **"08"** = alto uso de CPU
* **"0"** = temp OK
* **"1"** = está **plugado na tomada**

Ou seja, a chave é tipo um **snapshot codificado** do estado da máquina.
