# Tradicional x Minha Proposta

O método tradicional muitas vezes se limita a usar ferramentas de particionamento que apenas recriam a tabela de partição, sem garantir a limpeza completa de metadados antigos ou bootloaders que podem causar conflitos ou comportamentos inesperados mais tarde, pelo menos foi isso q passei ao usar o calamaris.

Meu método adota uma abordagem de "terra arrasada controlada", em que a combinação de `umount`, `swapoff`, `dmsetup remove`, `wipefs`, `sgdisk --zap-all` e `dd` garante que o disco esteja verdadeiramente limpo e pronto para a nova estrutura, eliminando potenciais fontes de conflito e assegurando um início limpo.

A criação explícita das partições com `sgdisk`, definindo tamanhos, tipos (typecodes) e nomes claros, estabelece uma base sólida e organizada para o SO e o sistema de arquivos, onde após essa configuração, caso eu queira trocar de SO, basta apenas sobreescrever o q é necesssario agilizando processso de formatação.&#x20;

A inclusão de `partprobe` e `udevadm settle` após cada mudança estrutural garante que o sistema operacional reconheça as alterações imediatamente, evitando inconsistências, resultando em um processo de preparação de disco muito mais robusto, confiável e previsível.

| **Característica**        | **Método Tradicional**                        | **Meu Método (Script)**                                      |
| ------------------------- | --------------------------------------------- | ------------------------------------------------------------ |
| **Limpeza Prévia**        | Opcional, muitas vezes apenas recria tabela   | Extensiva (`wipefs`, `zap-all`, `dd`)                        |
| **Desmontagem**           | Pode falhar se dispositivo estiver ocupado    | Forçada (`umount`, `swapoff`, `dmsetup remove`)              |
| **Remoção de Conflitos**  | Menos garantida                               | Alta probabilidade de eliminar bootloaders/metadados antigos |
| **Criação de Partições**  | Pode ser manual ou com padrões simples        | Automatizada, com tipos e tamanhos específicos (`sgdisk`)    |
| **Reconhecimento Kernel** | Pode precisar de reboot ou intervenção manual | Forçado (`partprobe`, `udevadm settle`)                      |
| **Robustez**              | Menor                                         | Muito maior, menos propenso a erros residuais                |

***
