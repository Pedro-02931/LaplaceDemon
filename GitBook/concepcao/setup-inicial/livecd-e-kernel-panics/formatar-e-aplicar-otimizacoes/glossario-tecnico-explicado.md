# Glossario Tecnico Explicado

| Item / Comando | Explicação Lógica                                                                | Explicação Eletrônica / Kernel                                                            | Acrônimo / Significado Técnico     |
| -------------- | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | ---------------------------------- |
| `IFS`          | Define qual caractere será usado para separar variáveis lidas via `read`         | Controla como o shell interpreta dados segmentados em buffers                             | _Internal Field Separator_         |
| `mkfs_opts`    | Armazena opções a serem passadas ao comando de formatação (`mkfs`)               | Define parâmetros físicos de layout (ex: blocos, rótulo)                                  | _Make Filesystem Options_          |
| `tune_opts`    | Parâmetros passados ao `tune2fs` para ajustes finos pós-formatação               | Modifica atributos como intervalo de fsck, journaling, timestamps                         | _Filesystem Tuning Options_        |
| `mount_opts`   | Opções de montagem para cada partição (noatime, discard, compress, etc)          | Instruções passadas ao VFS sobre comportamento de acesso                                  | _Mount Options_                    |
| `<<<`          | Redireciona _string literal_ como entrada padrão (stdin) para um comando         | Carrega valores diretamente do buffer de shell para o comando sem arquivos intermediários | _Here-string_                      |
| `eval`         | Interpreta e executa uma string como código do shell                             | Executa comandos gerados dinamicamente (ex: `eval mkfs.ext4 ...`)                         | _Evaluate expression as a command_ |
| `mkfs`         | Comando base para criação de sistemas de arquivos (`mkfs.ext4`, `mkfs.btrfs`...) | Escreve superblocos, tabelas de inodes, e estrutura básica do FS                          | _Make Filesystem_                  |
| `[[ -n ... ]]` | Testa se a variável contém algo (não vazia)                                      | Operação lógica no shell, não acessa hardware                                             | _Non-zero string length test_      |
| `tune2fs`      | Altera parâmetros de FS ext2/ext3/ext4 pós-formatação                            | Atua diretamente nos superblocos e flags do FS                                            | _Tune ext2/ext3/ext4 Filesystem_   |
| `mkswap`       | Inicializa uma partição como área de swap                                        | Marca blocos de disco com assinatura de swap reconhecida pelo kernel                      | _Make Swap_                        |
| `swapon`       | Ativa o swap recém-criado para uso imediato                                      | Integra a área de swap ao gerenciador de memória virtual                                  | _Swap On_                          |

***

### 🧠 LÓGICA FUNCIONAL DA `formatar_e_otimizar`

A função percorre todas as partições definidas na sua arquitetura e:

1. **Lê os parâmetros** do array `OTIMIZACOES`, quebrando em 4 partes: tipo de FS, opções de formatação, de ajuste e de montagem.
2. **Determina o número da partição** com base na ordem (EFI = 1, BOOT = 2, e as demais seguem numericamente).
3. **Formata com `mkfs`, ajusta com `tune2fs`**, e monta com opções específicas.
4. **Para swap**, usa `mkswap` e `swapon`, ativando na hora.
5. **Marcação de execução** evita repetir a operação — idempotência garantida.

***

### 🔌 INTERAÇÃO ELETRÔNICA / COMPORTAMENTO NO NÍVEL DE HARDWARE

* `mkfs.*` escreve estruturas fundamentais de dados diretamente no disco (superbloco, bitmap de inodes, etc.).
* `tune2fs` edita metadados internos, mexendo no tempo de fsck, comportamento de journal, etc.
* `mkswap` grava assinatura `SWAPSPACE2` no disco — reconhecida pelo kernel.
* `mount` cria um ponto lógico de entrada no VFS (Virtual Filesystem), conectando o espaço real do disco ao espaço de arquivos do Linux.
* `swapon` registra a partição de swap com o _memory manager_ do kernel, permitindo paginação via disco.

***

### 🔧 COMPORTAMENTO DETALHADO DAS LINHAS IMPORTANTES

```bash
IFS=' ' read -r fs mkfs_opts tune_opts mount_opts <<< "${OTIMIZACOES[$key]}"
```

**Desmonta o array OTIMIZACOES\[$key]** em 4 variáveis com base no separador IFS. Lido diretamente do array.

```bash
eval mkfs.$fs $mkfs_opts "$part"
```

**Constrói e executa dinamicamente** o comando de formatação correto. Ex: `mkfs.ext4 -q -L ROOT /dev/sda3`

```bash
[[ -n $tune_opts ]] && eval tune2fs $tune_opts "$part"`
```

Se `tune_opts` não estiver vazia, executa ajustes adicionais no FS (fsck, journaling...).

```bash
mkswap -L SWAP "$DISK$idx" && swapon "$DISK$idx"`
```

Inicializa e ativa imediatamente a partição swap.

***

Se quiser, posso expandir com:

* Valores comuns para `tune2fs` e o que cada um impacta.
* Explicações de como o kernel gerencia `swapon` internamente (com `vmstat`, `free`, etc.)
* Ou até desenhar um fluxograma da função pra documentação visual.

Quer seguir por algum desses?
