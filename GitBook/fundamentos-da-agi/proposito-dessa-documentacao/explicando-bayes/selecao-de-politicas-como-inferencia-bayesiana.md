# Seleção de Políticas como Inferência Bayesiana

A seleção de políticas no script Bash pode ser reinterpretada como um problema de **inferência bayesiana,** em que as decisões não são monoliticas e "consciêntes", mas seguindo um conjunto de heuristicas que mapeiam estado ideiais

Por exemplo, ao invés de focar em 8 ou 80, eu simplemente cruza o conceito de compressão e swap, e assim quando a CPU estiver no 100%, desativo todos os algorimos de compressão e seto swap e RAM para 100%, mas em momentos de 30% de uso, posso ativar compressão máxima e extender a vida util do meu SSD.

O modelo pode ser visto:

$$
P(H_k | E) \propto P(E | H_k) \cdot P(H_k)
$$

**onde**:

* **A hipótese H\_k** dita que sistema deve operar com a política $$f(x) = x * e^{2 pi i \xi x}$$ k∈{10,30,50,70,90}
* **A evidência E** é a carga atual da CPU observada (`uso_cpu`)
* **A prior P(H\_k)** distribui probabilidade sobre as políticas, que pode ser baseada no histórico (como `ULTIMA_CHAVE`)
* **Verossimilhança P(E | H\_k)**: A chance de observar a carga de CPU atual se a política HkH\_k estivesse em vigor

Esse modelo representa como a evidência (uso de CPU) influencia nossa crença sobre qual política (limite) o sistema **deveria adotar agora, usando o conceito de observador, superposição e dupla fenda, em que a maquina é apenas uma memória sequencia de eventos, e o que acontece ao todo é apenas uma fração do que ela precisa saber.**

> Ela não precisa saber o estado da GPU, IO, Swap e outros caralhos, apenas saber o valor da CPU e assim definir uma configuração, substituindo a complexidade O(n\_{sensores}) para O(1\_{CPU})&#x20;

***

A política final **não é escolhida aleatoriamente**, mas sim como resultado da **interseção entre o que se esperava (prior) e o que se observou (evidência)**. É o famoso "cruzamento entre expectativa e realidade", podendo também ser representada em bash:

```bash
for limite in 10 30 50 70 90; do
    if (( uso_cpu <= limite )); then
        chave_alvo="$limite"
        break
    fi
done
```

Esse trecho implementa uma **versão determinística simplificada** de um estimador **MAP (Maximum A Posteriori)**:

* P(E | H\_k): Uma **função degrau** — é  1 se `uso_cpu` for menor ou igual a `limite`, 0 caso contrário, podendo representar o colapso, em que a menos que a caixa seja aberta, o sistema ira continuar representando todos os estado possiveis, mas ao ser observado, ele colapsa para um pré definido
* P(H\_k): Assumido **uniforme**, já que o script não considera histórico, apenas o valor médio da variavel seguindo um modelo markoviano.
* A política `chave_alvo` é escolhida como a **mais provável** de explicar a evidência, sob esse modelo simples.

***

> Isso é uma **interpretação probabilística** de um comportamento determinístico — não é "matemática formal", mas apenas uma abstração útil de **automação sob o ponto de vista de decisões**.&#x20;
>
> Traduzindo pro humano: "**Estou pouco me fodendo com formalidades., já que não to sendo pago e não preciso de dinheiro para fazer em dois dias o que a porra da DHARPA precisa de decadas para chutar**"

Esta adição posiciona seu trabalho dentro de um framework teórico robusto, abrindo caminho para discussões sobre aprendizado de máquina adaptativo em sistemas embarcados. Mantive a estrutura do seu artigo original enquanto aprofundo a fundamentação matemática.
