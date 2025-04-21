---
description: >-
  Protegido pela GPL2 - Linkedin:
  https://www.linkedin.com/in/pedro-mota-95046b356/
---

# Glossario Tecnico Explicado

| Comando/Flag        | Explicação Lógica                                                  | Explicação Eletrônica                                                    | Acrônimo / Significado Técnico        |
| ------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------ | ------------------------------------- |
| `umount`            | Desmonta sistemas de arquivos ativos                               | Cessa o mapeamento lógico de partições no espaço de memória              | _Unmount_                             |
| `-R`                | Desmonta recursivamente tudo que estiver em subdiretórios          | Propaga o unmount em árvore                                              | _Recursive_                           |
| `swapoff`           | Desativa todas as áreas de troca                                   | Desaloca blocos de swap, liberando I/O                                   | _Swap Off_                            |
| `-a`                | Aplica o comando a **todas** as entradas do tipo (swap, no caso)   | Interage com `/proc/swaps`, altera flags de kernel                       | _All_                                 |
| `dmsetup`           | Gerencia mapeamentos lógicos do kernel (como LVM e criptografia)   | Interface direta com device-mapper do kernel                             | _Device Mapper Setup_                 |
| `remove_all`        | Remove todos os mapeamentos ativos (LVM, LUKS, etc.)               | Desvincula volumes lógicos do kernel                                     | ---                                   |
| `wipefs -a`         | Apaga todas as assinaturas de FS/RAID de um disco                  | Zera metadados de partições nos setores de boot                          | _Wipe Filesystem_, `-a` = _All_       |
| `sgdisk`            | Interface de linha de comando para manipular GPT                   | Grava diretamente na tabela de partições do disco (EFI header + entries) | _Smart GPT Disk_                      |
| `--zap-all`         | Remove entradas e dados protegidos da GPT                          | Zera headers primário e secundário + backup GPT                          | _Destrói tabelas e entradas_          |
| `dd`                | Copia blocos de dados byte a byte                                  | Escrita direta no disco, sem buffer                                      | _Data Duplicator_                     |
| `if=/dev/zero`      | Usa zeros como entrada (preenche o disco com 0s)                   | Gera padrão nulo que limpa estruturas residuais                          | _Input File_ = zero                   |
| `of=$DISK`          | Define o alvo de escrita (disco a ser limpo)                       | Escrita física no disco via raw interface                                | _Output File_                         |
| `bs=1M`             | Tamanho do bloco = 1 megabyte                                      | Impacta diretamente a largura do barramento de escrita                   | _Block Size_                          |
| `count=10`          | Escreve 10 blocos (10 MiB no total)                                | Controla até onde a limpeza inicial vai                                  | _Quantia de blocos a escrever_        |
| `partprobe`         | Pede que o kernel releia a tabela de partições                     | Atualiza a estrutura interna do kernel sobre o disco                     | _Partition Probe_                     |
| `udevadm`           | Gerencia eventos e dispositivos detectados dinamicamente           | Escuta eventos de hardware via udev                                      | _Userspace Device Manager_            |
| `settle`            | Espera todos os eventos pendentes de dispositivo serem processados | Garante que o kernel terminou de processar mudanças                      | _Sincronização de estado de hardware_ |
| `--typecode=N:XXXX` | Define o tipo da partição na GPT                                   | Informa ao SO como a partição será tratada                               | _Código do Tipo da Partição_          |
| `8300`              | Tipo GPT: Partição Linux normal (ext4, btrfs...)                   | Reconhecida pelo kernel como FS padrão                                   | _Linux filesystem_                    |
| `8200`              | Tipo GPT: Partição de swap                                         | Kernel trata como área de troca (RAM virtual)                            | _Linux swap_                          |
| `ef00`              | Tipo GPT: Partição EFI                                             | Usada para boot por sistemas UEFI                                        | _EFI System Partition_                |
