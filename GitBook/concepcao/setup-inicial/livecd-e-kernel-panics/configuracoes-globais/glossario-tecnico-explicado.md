---
description: >-
  Protegido pela GPL2 - Linkedin:
  https://www.linkedin.com/in/pedro-mota-95046b356/
---

# Glossario Tecnico Explicado

| Opção                    | Nível Lógico                                           | Nível Eletrônico                                                  | Acrônimo / Explicação                            |
| ------------------------ | ------------------------------------------------------ | ----------------------------------------------------------------- | ------------------------------------------------ |
| `vfat`                   | Suporte a FAT usado em EFI, compatível universal       | Simples, baixo overhead. Sem journaling → menos escritas físicas. | Virtual FAT (File Allocation Table)              |
| `-F32`                   | Força formatação FAT32                                 | Limita estrutura de arquivos, ideal pra UEFI                      | FAT32: 32-bit File Allocation Table              |
| `noatime`                | Não grava timestamp de leitura de arquivos             | Evita escrita desnecessária no disco                              | No Access Time                                   |
| `nodiratime`             | Não grava timestamp ao abrir diretórios                | Reduz ainda mais I/O de leitura de estrutura                      | No Directory Access Time                         |
| `flush`                  | Força sincronização de buffers após escrita            | Mais segura, mas mais lenta: escreve direto no disco              | Sincronização forçada                            |
| `ext4`                   | Sistema equilibrado, robusto, com journaling           | Compatível com tudo, rápida, confiável                            | Fourth Extended File System                      |
| `-q -L`                  | `-q`: modo quiet, `-L`: define label                   | Apenas interação com metadata, sem impacto direto                 | Quiet / Label                                    |
| `data=writeback`         | Dados escritos antes do journaling (não sincronizados) | Rápido, mas propenso à perda em queda de energia                  | Política de escrita preguiçosa                   |
| `discard`                | Informa ao SSD quais blocos não são mais usados        | Gatilho para o comando TRIM via hardware                          | Descarte de blocos não utilizados                |
| `btrfs`                  | Sistema copy-on-write, suporta compressão e snapshots  | Dinâmico, moderno, pode fragmentar sem autodefrag                 | B-tree File System                               |
| `compress=zstd:3`        | Compressão com Zstd em nível 3                         | Usa CPU leve, reduz escrita física                                | Zstandard compressão (nível 3)                   |
| `space_cache=v2`         | Cache de espaço livre otimizado                        | Menos consulta no disco para alocação                             | Segunda versão do cache de espaço do Btrfs       |
| `ssd`                    | Ativa heurísticas otimizadas para SSD                  | Reduz desgaste, melhora TRIM e flushing                           | Solid State Drive optimization                   |
| `journal_data_writeback` | Usa journal, mas não sincroniza dados                  | Grava journal depois, aumenta performance                         | Ext4 flag: escreve journal sem garantia de ordem |
| `data=journal`           | Primeiro grava dados no journal, depois no local final | Mais seguro, mais uso de I/O                                      | Full journaling mode                             |
| `barrier=0`              | Desliga garantias de ordem via cache de disco          | Risco em power loss, mas ganho de performance                     | Desativa flush de write barrier                  |
| `commit=120`             | Delay de 120s pra sync com disco                       | Menos escrita, mais performance, risco se cair energia            | Commit interval em segundos                      |
| `autodefrag`             | Fragmentação corrigida dinamicamente                   | Reordena blocos com base em acesso real                           | Auto Defragmentação                              |
