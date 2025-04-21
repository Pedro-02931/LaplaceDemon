---
description: >-
  Protegido pela GPL2 - Linkedin:
  https://www.linkedin.com/in/pedro-mota-95046b356/
---

# LiveCD e Kernel Panics

Bom, a primeira parte do que eu fiz foi recriar o instalador do LiveCD copiando os arquivos da memoria RAM para o SSD e particionando ele em volumes lógicos, assim simulando uma neuroplasticidade com Deamon

> Ignore a parte de volumes lógicos e neuroplasticidade. Sou muito burro para fazer isso, então só fiz a formatação no terminal e usei o next next finish, e o script é apenas teorico de estudo, pq dps do 3 Kernell Panic no Boot, tirei o dedo no cu e desisti

Assim acabei gerando esse ritual satânico que deve ser rodado no instalador para a formatação do HD, que pode ser executado direto do curl.

{% code overflow="wrap" %}
```
curl -s https://raw.githubusercontent.com/Pedro-02931/LaplaceDemon/refs/heads/prototypes/storage/static_Conf/format.sh \
| bash
```
{% endcode %}

No caso, o meu objetivo nessa seção é quebrar o script que produzi explicando por função, separanando por artigos. segue a batida.

