---
description: >-
  Protegido pela GPL2 - Linkedin:
  https://www.linkedin.com/in/pedro-mota-95046b356/
---

# Cabeçalho

Antes de sair formatando feito louco, precisamos preparar o ambiente e definir as regras do jogo, onde tudo deve seguir um padrão que garanta a comunicação entre o usuário e o computador, onde um reflete o outro&#x20;

> Humanos conseguem se conectar com qualquer coisa, e quanto mais organizado essa coisa for no fluxo de dados, mais "humana" ela se torna.

### O Que Foi Feito

o script começa definindo onde guardar registros (`LOG_DIR`, `LOG_FILE`) e um controle (`CONTROL_FILE`) para não repetir ações destrutivas, onde foquei mais em remover o que deu certo, trocando blocos gigantescos de informação inutil em echos diminutivos, onde para discernir de um e outro basta ver se foi para o stdder.

O `LOG_DIR` foi focado mais para a otimização e debug com o uso de LLMs, onde o mapeamento de forma mais eficiente é essencial, e futuramente quero fazer uma função de compressão entrópica para adicionar uma camada de metacognição usando fluxos de textos.

A linha `set -euo pipefail` manda o script parar imediatamente se qualquer comando falhar, evitando cascata de erros, enquanto o `trap` é o botão de emergência que avisa onde o problema aconteceu antes de abortar a missão, assim eu consigo debugar de forma mais eficiente, onde a quantidade de dados iniciais que define a acertividade final.

{% code overflow="wrap" %}
```bash
#!/bin/bash
# -*- coding: utf-8 -*-
# (...) Cabeçalho de licença e comentários (...)

set -euo pipefail

# ----------------------------------------
# ARQUIVOS DE LOG E CONTROLE
# ----------------------------------------
LOG_DIR="/log"
LOG_FILE="$LOG_DIR/vemCaPutinha.log"
CONTROL_FILE="$LOG_DIR/vemCaPutinha_control.log"
mkdir -p "$LOG_DIR"
touch "$LOG_FILE" "$CONTROL_FILE"

# ----------------------------------------
# 🚨 TRAP DE ERROS
# ----------------------------------------
trap 'echo "Erro na linha $LINENO" | tee -a "$LOG_FILE" >&2; exit 1' ERR
```
{% endcode %}
