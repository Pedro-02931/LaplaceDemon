---
description: >-
  Protegido pela GPL2, isso significa que se me copiar sem nem ao menos me fazer
  referência, dá o bumbum - Linkedin:
  https://www.linkedin.com/in/pedro-mota-95046b356/
---

# Explicando Bayes

Bom, indo para a parte um pouco mais parruda, o conceito de sistemas autoadaptativos exige uma ponte entre observação empírica e ação proativa, onde a chave não está na complexidade ao carregar uma carahada de parametros, mas e sim na simplicidade de escoher a mellhor opçõa já mapeada.&#x20;

O enfoque bayesiano emerge da premissa que _todo estado do sistema é uma crença probabilística_, uma fé baseado no que acontece, em que um estimulo está relacionado a uma ação complexa de n-dimensões, onde não precisa ser constatemente atualizada pelo sistema.

Assim como você não aprende nada do zero, sempre tendo que se inspirar nos outros para começar alo, o sistema pode simplesmente acreditar que para determinada situação, aquela seja a melhor escolja, bem mais elegante e simples do que depender de tensor-flow para fazer algo básico.

A filosofia implícita é:

1. **Prior (Crença Inicial):** Representado pelo estado armazenado em `LAST_STATE`, carrega a memória histórica do sistema

* No caso, a ideia é fazer uma operação media para poder suavisar a mudança de estados.&#x20;
* No meu caso, baseei excusivamente no uso de CPU como ponta de lança, onde ás vezes ela atinge picos momentaneos de 99% quando eu abro um app devido a necesidade de mudança brusca
* O objetivo da média é suavizar, evitando a latencia de estados, onde 1 ponto divergente raramente pesa mais que 10 pontos padrões médios consectivos, assim definindo uma onda ao invés de uma derivada&#x20;

2. **Likelihood (Evidência):** A carga instantânea da CPU, filtrada pela média móvel exponencial (EMA)

* Aqui ela mede o estado atual e faz um append na avriave de referencia, e se caso a variavel de referencia estivver em um range divergente, ele altera a configuraçã, garantindo a melhor opção na tabela de cruzamento

3. **Posterior (Decisão):** A atualização de estados através da função `stealth_adaptation`, que age como um estimador MAP (Maximum A Posteriori)

* Aqui ele carrega a segunda coluna que carrega as palavras chaves, onde seguindo o princiio de compressão entrópica, o sistema através de laços for loop, subtitui as palavras carregadas de configuração, e as linhas de execuão são executadas sequencialmente e atualizadas
* Assim, ao invés de mapear infinitas opções possiveis, basta saer o que já foi ensinado a maquina, e ela ira decidir com base em medições, trocando uma derivada termica por uma integral de adaptação

