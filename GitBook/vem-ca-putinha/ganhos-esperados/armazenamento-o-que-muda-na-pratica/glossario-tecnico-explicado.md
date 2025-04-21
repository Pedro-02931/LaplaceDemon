# Glossário Técnico Explicado

| Termo            | Nível Lógico                                                    | Nível Eletrônico                               | Acrônimo / Etimologia                       |
| ---------------- | --------------------------------------------------------------- | ---------------------------------------------- | ------------------------------------------- |
| **EFI**          | Interface entre firmware e sistema operacional (substitui BIOS) | Armazenado em flash ROM da placa-mãe           | _Extensible Firmware Interface_             |
| **vfat**         | Sistema de arquivos usado em EFI; compatível com FAT32          | Opera com estruturas simples, sem journaling   | _Virtual File Allocation Table_             |
| **bootloaders**  | Software que carrega o kernel (GRUB, systemd-boot, etc.)        | Executado diretamente pelo EFI/BIOS            | —                                           |
| **noatime**      | Evita atualizar timestamp de acesso a cada leitura              | Reduz escrita na NAND flash do SSD             | _No Access Time_                            |
| **nodiratime**   | Igual ao `noatime`, mas só para diretórios                      | Evita metadata write ao acessar pastas         | _No Directory Access Time_                  |
| **flush**        | Força flush de buffer I/O (útil para VFAT)                      | Garante que dados sejam persistidos no SSD     | —                                           |
| **wear de SSD**  | Desgaste por ciclo de Program/Erase (P/E)                       | NAND flash tem vida útil limitada por blocos   | _Wear_ = desgaste físico                    |
| **journaling**   | Sistema que registra operações antes de aplicá-las              | Mais escrita (wear) porém mais seguro          | —                                           |
| **initramfs**    | Mini sistema de arquivos usado para iniciar o kernel            | Carregado na RAM, vem do `/boot`               | _Initial RAM Filesystem_                    |
| **writeback**    | Dados escritos primeiro no cache, depois no disco               | Acelera performance, aumenta risco em crash    | —                                           |
| **tune2fs**      | Utilitário para alterar configs de ext2/ext3/ext4               | Modifica metadados via comandos ioctl          | _Tune ext2/ext3/ext4 Filesystem_            |
| **fragmentação** | Arquivos divididos em blocos não-contíguos                      | Aumenta latência de leitura                    | —                                           |
| **commit**       | Intervalo de tempo para gravar metadados no disco               | Escreve no SSD a cada X segundos               | —                                           |
| **stripe**       | Alinhamento de blocos com RAID ou SSD                           | Melhora throughput em gravações paralelas      | _Stripe size_                               |
| **btrfs**        | FS moderno com snapshot, compressão, RAID                       | Alta eficiência, especialmente com SSD         | _B-tree File System_                        |
| **zstd**         | Algoritmo de compressão rápido e eficiente                      | Consome CPU, reduz I/O no SSD                  | _Zstandard_ (Facebook)                      |
| **autodefrag**   | Btrfs detecta e reorganiza arquivos fragmentados                | Leitura de arquivos se torna linear            | _Automatic Defragmentation_                 |
| **space\_cache** | Cache de espaço livre em Btrfs                                  | Acelera alocação de blocos                     | —                                           |
| **barrier**      | Garante ordem de escrita entre journal e dados                  | Crucial para integridade após falha de energia | —                                           |
| **nodealalloc**  | Aloca blocos no momento da escrita                              | Menos performance, mais segurança              | _No Delayed Allocation_                     |
| **nobh**         | Evita usar buffer heads (apenas direto via page cache)          | Leve ganho em I/O, menos abstração             | _No Buffer Heads_                           |
| **OverlayFS**    | FS que junta camadas: base + mudanças (ex: LiveCD)              | Leitura rápida e gravação em camada superior   | _Overlay File System_                       |
| **squashfs**     | FS comprimido, somente leitura                                  | Excelente para imagens imutáveis               | _Squashed File System_                      |
| **f2fs**         | FS otimizado para NAND flash/SSD                                | Reduz wear-leveling, melhora latência          | _Flash-Friendly File System_                |
| **pri**          | Define prioridade de swap (ZRAM > SSD)                          | Valor mais alto = mais usado                   | _Priority_                                  |
| **TRIM**         | Informa ao SSD quais blocos podem ser apagados                  | Ativa o garbage collector interno              | —                                           |
| **mq-deadline**  | Escalonador I/O focado em latência garantida                    | Multiqueue + deadline por requisição           | _Multi-Queue Deadline Scheduler_            |
| **cachepool**    | Volume auxiliar para cache em LVM                               | Cache de escrita/leitura em SSDs               | —                                           |
| **ssd\_cache**   | Bloco de cache entre SSD e HD (LVM, bcache, etc.)               | Acelera acesso a dados frequentemente lidos    | —                                           |
| **modprobe**     | Carrega módulos do kernel dinamicamente                         | Usa `insmod`, lida com dependências            | _Module Probe_                              |
| **crc32c-intel** | Módulo com aceleração via instruções Intel (SSE4.2)             | Verifica integridade via checksum rápido       | _Cyclic Redundancy Check 32-bit Castagnoli_ |
