---
description: >-
  Protegido pela GPL2 - Linkedin:
  https://www.linkedin.com/in/pedro-mota-95046b356/
---

# Memoria de Curto Prazo

O cache em `LAST_STATE` funciona como um _modelo de transição de estados_ bayesiano, onde através de calculos médios, consegui aplicar uma cadeia markoviana para saber a demanda do sistema, e a cada ciclo, á a função de colapso de onda:

```bash
[[ "$chave_alvo" == "$ULTIMA_CHAVE" ]] && return 0
```

O objetivo é garantir que não seja alterado de forma desnecessária o estado, onde você ignora o desnecessário e foca apenas no diferente

> Exemplo bom é quando você ignora o barulho do ar condicionado/ventilador se for um pobre fodido como eu pois está a 4 horas ouvindo isso sem mudar, mas não consegue ignorar um barulho de tiro vindo da rua por exemplo
>
> Uma vc sabe que vai acontecer, e pode acontecer literalmente tudo, no outro, vc tem que prestar atenção para saber o que está acontecendo, mas esse foco gasta energia mental!

**Diagrama do Processo Bayesiano:**

```
[Prior] -> [Coleta de Evidência] -> [Atualização Bayesiana] -> [Decisão MAP] -> [Atuação]
  ^                                                               |
  |_______________________________________________________________|
```

```
```

