---
description: >-
  Protegido pela GPL2, isso significa que se me copiar sem nem ao menos me fazer
  referência, dá o bumbum - Linkedin:
  https://www.linkedin.com/in/pedro-mota-95046b356/
---

# Proposito Dessa Documentação

O objetivo dessa alucinação é a documentação feita por um autista que desenvolvu um sistema autoadaptativo usando bash, em que ele se otimiza em cargas de maior demanda extraindo o máximo do dispositivo, e entra em economia em de menor demanda com base numa média métrica de chaves, no caso a CPU.

MAS o conceito é bem simples:

1. Carrega-se uma tabela de cruzamento com chaves que representam um denominador comum
2. Essas chaves carregam plavras chaves para comandos Linux
3. E compara o estado atual(um valor médio das ultimas n medições para evitar mudanças bruscas e falsos positivos) com o valor da tabela.
4. Caso ainda esteja dentro do ultimo range, retorna um e deixa como esta evitando sobreescrita desncessario
5. Caso esteja diferente, ele executa uma função harmonica de transição garantindo que a frequencia exibida pela maquina permaneça imperceptivel para o humano na mudança de estados
6. E através de um timer, odendo ser um while como quando execuei os teste, ou um deamon rodando por baixo para otimização constante e permissoes supremas, imita-se o ciiclo ultradiano

> A filosofia por trás desse esquema é: "O ppoder de processamento atual é o suficiente para literalmente tudo, agora é fazer a mesma coisa com o mnimo possível!"

