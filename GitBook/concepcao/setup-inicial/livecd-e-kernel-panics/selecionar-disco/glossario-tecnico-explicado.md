---
description: >-
  Protegido pela GPL2 - Linkedin:
  https://www.linkedin.com/in/pedro-mota-95046b356/
---

# Glossario Tecnico Explicado

| Comando              | Nível Lógico                                                        | Nível Eletrônico                                                     | Acrônimo / Significado técnico                       |
| -------------------- | ------------------------------------------------------------------- | -------------------------------------------------------------------- | ---------------------------------------------------- |
| `lsblk`              | Lista dispositivos de bloco conectados ao sistema (HDs, SSDs, etc.) | Acessa `/sys` e `/proc/partitions`; não interage direto com hardware | _List Block Devices_                                 |
| `-d`                 | Mostra apenas discos, ignora partições                              | Evita redundância, menos carga de I/O                                | _Device only_                                        |
| `-p`                 | Mostra o caminho completo dos dispositivos (ex: /dev/sda)           | Mais seguro para scripts: evita confusão com nomes parciais          | _Path_                                               |
| `-n`                 | Remove o cabeçalho da saída                                         | Otimiza para uso com `nl` e `sed` — menos texto, mais precisão       | _No headings_                                        |
| `-o NAME,SIZE,MODEL` | Define colunas a exibir: nome do device, tamanho, modelo do disco   | Coleta direto da sysfs com parsing mínimo                            | _Output columns_                                     |
| `nl -w2 -s'. '`      | Numera linhas com 2 dígitos, separados por ponto                    | Não altera dados; só organiza visualmente a escolha                  | _Number Lines_ (`-w`: largura, `-s`: separador)      |
| `read -p "..." idx`  | Lê input do usuário e armazena na variável `idx`                    | Interação por stdin, pausa o shell                                   | _Read with prompt_                                   |
| `sed -n "${idx}p"`   | Extrai apenas a linha N do input (`p` = print)                      | Leitura de stream na RAM; sem impacto no disco                       | _Stream EDitor_                                      |
| `[[ -z "$DISK" ]]`   | Verifica se a variável está vazia                                   | Processo lógico no shell; pura RAM                                   | `-z`: _zero length_ → verifica string vazia          |
| `tee -a "$LOG_FILE"` | Escreve a mensagem no terminal **e** adiciona ao arquivo de log     | Grava no terminal (stdout) e em arquivo (write via FS)               | _T_-shaped split: duplica a saída para dois destinos |
| `exit 1`             | Encerra o script com erro                                           | Envia código de erro ao sistema                                      | Código de saída (1 = erro padrão)                    |
