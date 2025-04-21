# Tradicional x Minha Proposta

## Ganhos em Relação Entre o Método Tradicional e o Meu

A formatação tradicional geralmente aplica o mesmo sistema de arquivos (quase sempre ext4) com opções de montagem padrão (`relatime`, `data=ordered`) para todas as partições (exceto EFI e swap), essa abordagem "tamanho único" ignora as diferentes necessidades de cada parte do sistema e desperdiça o potencial de otimização, especialmente com SSDs.

As opções padrão causam escritas excessivas de metadados (`relatime`), não aproveitam compressão para economizar espaço e escritas, não ativam TRIM contínuo (`discard`) para manter o SSD ágil e usam journaling (`data=ordered`) que pode segurar um pouco o desempenho de escrita em troca de uma segurança que nem sempre é necessária em todas as partições.

Meu método aplica um "tuning" específico para cada partição, reconhecendo que `/tmp` tem um perfil de uso diferente de `/home` ou `/var`, usei `btrfs` onde suas funcionalidades (compressão, snapshots, checksums) trazem mais benefícios (`root`, `home`), e `ext4` otimizado onde estabilidade e compatibilidade são chave (`var`, `tmp`, `usr`, `boot`);&#x20;

`noatime`/`nodiratime` cortam escritas de acesso drasticamente, `compress=zstd` reduz o volume de dados escritos (aumentando vida útil do SSD e velocidade de leitura/escrita efetiva ao custo de um pouco de CPU), `discard` mantém o SSD limpo, `commit=120` agrupa escritas de metadados, `data=writeback` acelera escritas onde seguro, `space_cache`/`ssd` otimizam para SSDs, e `nodev/nosuid/noexec` em `/tmp` adicionam segurança.&#x20;

O uso de `swapfile` em vez de partição swap adiciona flexibilidade pós-instalação, resultando em um sistema significativamente mais rápido, responsivo, durável (especialmente o SSD) e seguro.

### Tabela de Explicação: Formatação e Otimização

| **Característica**         | **Método Tradicional (Padrão Ext4)**     | **Meu Método (Otimizado)**                                                            |
| -------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------- |
| **Filesystem (Root/Home)** | Ext4                                     | Btrfs com compressão Zstd                                                             |
| **Metadados de Acesso**    | `relatime` (escrita ocasional)           | `noatime`/`nodiratime` (sem escrita)                                                  |
| **Compressão**             | Nenhuma                                  | Zstandard (nível 1 ou 3)                                                              |
| **TRIM (SSD)**             | Geralmente periódico (fstrim.timer)      | Contínuo (`discard`)                                                                  |
| **Journaling (Data)**      | `data=ordered` (mais lento, mais seguro) | `data=writeback` (mais rápido, seguro na maioria dos casos) ou `data=journal` em /var |
| **Commit Metadados**       | Padrão baixo (e.g., 5 segundos)          | Aumentado (`commit=120`) em /usr                                                      |
| **Otimização SSD**         | Básica                                   | Explícita (`ssd`, `space_cache=v2` no Btrfs)                                          |
| **Swap**                   | Partição fixa                            | Arquivo (`swapfile`), flexível                                                        |
| **Segurança /tmp**         | Padrão                                   | Reforçada (`nodev`, `nosuid`, `noexec`)                                               |
| **Performance Geral**      | Boa                                      | Excelente, especialmente em SSDs e multi-tarefa                                       |
| **Vida Útil SSD**          | Normal                                   | Aumentada significativamente (menos escritas)                                         |

***
