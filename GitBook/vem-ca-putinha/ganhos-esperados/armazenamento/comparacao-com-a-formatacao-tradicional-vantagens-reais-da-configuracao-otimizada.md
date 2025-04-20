# Comparação com a Formatação Tradicional: Vantagens Reais da Configuração Otimizada

#### 1. Vida Útil do SSD (Resistência ao Desgaste)

Instalação padrão escreve o tempo todo, acessando arquivo, vendo video, qualquer coisa, o que pode causar um desgaste desnecessário em todo o disco

> Toda vez que o sistema grava um metadado inútil, uma célula do SSD morre um pouco por dentro, acontecendo milhares de vezes por dia, não tão diferente do metabolismo humano!

Com as otimizações que fiz:

*   `noatime`, `nodiratime`: corta totalmente escrita de metadados inúteis de acesso, reduzindo em teoria o volume de gravações em 60% ou mais.

    > * **O que fazem:** Impedem o sistema de registrar a hora do último acesso a arquivos e diretórios, respectivamente. Normalmente, toda vez que você acessa um arquivo (mesmo que seja só para ler), o sistema atualiza essa informação nos metadados do arquivo.
    > * Essa atualização constante de metadados significa que o SSD precisa escrever dados com muita frequência, mesmo para operações simples de leitura.&#x20;
    > * Ao desativar essa funcionalidade, você corta um volume enorme de escritas desnecessárias, já que a maioria dos usuários não precisa saber exatamente a hora do último acesso aos arquivos.
*   `discard`: ativa o TRIM constante, limpando os blocos no momento em que são liberados, em vez de acumular e mandar uma faxina geral uma vez por semana.

    > * **O que faz:** O TRIM é um comando que informa ao SSD quais blocos de dados não estão mais em uso (por exemplo, após a exclusão de um arquivo).
    > * Sem o TRIM, quando você exclui um arquivo, o SSD ainda mantém os dados fisicamente nos blocos até que precise sobrescrevê-los.levando a um acúmulo de blocos "sujos" que precisam ser apagados antes de novas escritas, o que é um processo mais demorado e desgastante para o SSD.&#x20;
    > * O `discard` (TRIM contínuo) avisa o SSD imediatamente quando um bloco é liberado, permitindo que ele faça a limpeza desses blocos em segundo plano, otimizando as futuras operações de escrita e evitando a degradação do desempenho ao longo do tempo.
*   `compress=zstd:3`: reduz em até 50% a quantidade de dados que o sistema precisa escrever.

    >
    >
    > * **O que faz:** Ativa a compressão dos dados que serão escritos no SSD usando o algoritmo Zstandard (nível 3 de compressão). Isso significa que os arquivos são compactados antes de serem gravados.
    > * Ao reduzir o tamanho dos dados que precisam ser escritos, o sistema efetivamente grava menos informações no SSD para armazenar a mesma quantidade de dados "visíveis" para você.&#x20;
    > * Em teoria, uma redução de até 50% significa que, para cada 1GB de dados, apenas 500MB (ou menos) são realmente gravados no disco. diminuindo drasticamente o volume total de escritas necessárias.
*   `commit=120`: adia escrita de metadados pra até dois minutos, agrupando e mandando tudo junto, ao invés de escrever grão a grão.

    > * **O que faz:** Define um intervalo de tempo (120 segundos, ou dois minutos) para que os metadados das operações de escrita sejam agrupados e escritos de uma só vez.&#x20;
    > * Normalmente, esses metadados são escritos no SSD quase que instantaneamente após cada operação, o que é ordem de grandezas ineficiente.
    > * Em vez de escrever os metadados de cada pequena alteração individualmente, o sistema espera acumular várias alterações ao longo de dois minutos e as escreve em um lote único, reduzindo o número de operações de escrita separadas, tornando o processo mais eficiente e diminuindo o desgaste do SSD.

**Resultado:** a vida útil do SSD aumenta de 20% a 40%. Se teu SSD aguentaria 3 anos em uso intenso, agora passa fácil dos 5 ou 6 sem virar peso de papel.

#### 2. Desempenho (Tempo de Resposta e Velocidade Real)

Sistema padrão usa journaling agressivo, escreve sincronamente, e ainda mete agendador de I/O que parece feito pra disco de 2004, resultando: latência escrota, abertura de apps lenta, boot preguiçoso, e possivelmente um fio-terra surpresa inesperado.

Com as otimizações:

*   `data=writeback`: o journaling não encurrala cada bit que passa, acelerando gravações e, no contexto certo, é totalmente seguro.

    > * **O que faz:** Em vez de registrar cada modificação de dados _antes_ de escrevê-la no disco (como no modo `ordered` ou `journal`), o `writeback` apenas registra os metadados (informações sobre a estrutura do arquivo, como nome, tamanho, etc.) antes da escrita dos dados, e os dados em si são escritos no disco em algum momento depois.
    > * Como o sistema não precisa esperar que os dados sejam gravados _e_ registrados no journal antes de considerar a operação concluída, as gravações se tornam mais rápidas.&#x20;
    > * No contexto certo (como em sistemas com uma boa quantidade de memória cache e um fornecimento de energia estável, onde é o padrão a menos que você more em Cuba ou na Venezuala(o que duido muito pois para entender esse artigo o minimo é ser alfabetizado)), o risco de perda de dados em caso de falha de energia é minimizado, pois os metadados que garantem a consistência do sistema de arquivos são registrados.
*   `tmpfs` pro `/tmp`: arquivos temporários vão pra RAM, onde são lidos e escritos quase instantaneamente.

    > * **O que faz:** Monta o diretório `/tmp` (usado para armazenar arquivos temporários criados por aplicativos) em um sistema de arquivos virtual chamado `tmpfs`.&#x20;
    > * O `tmpfs` usa a RAM (memória de acesso aleatório) e/ou o espaço de swap para armazenar os dados, e dado que o Linux tende a ser ordem de grandeza mais leve, é melhor usar 80% da RAM em carga máxima do que usar 20% da RAM e 80% do swap (puta configuração burra, mas quem sou eu? apenas um cara no primeiro curso tecnico)
    > * A RAM é significativamente mais rápida que um SSD ou HDD para operações de leitura e escrita, e dado que os padrões atuais são pelo menos 16 GB, e o Linux base raramente usa mais do que dois GB, é bem mais inteligente expremer ao máximo o sistema.&#x20;
    > * Ao mover os arquivos temporários para a RAM, as operações que envolvem esses arquivos (criação, leitura, escrita, exclusão) se tornam muito mais rápidas, melhorando o desempenho geral do sistema.&#x20;
    > * Além disso, como os dados são armazenados na RAM, não há desgaste no SSD devido a escritas e exclusões frequentes de arquivos temporários, focando em aumentar a vida util do SSD.
*   `mq-deadline`: escalonador de I/O otimizado pra NVMe, entrega previsibilidade e desempenho em multitarefa pesada.

    > * **O que faz:** `mq-deadline` é um escalonador de entrada/saída (I/O) projetado para dispositivos de armazenamento de alta velocidade, como SSDs NVMe.&#x20;
    > * Um escalonador de I/O é responsável por decidir a ordem em que as requisições de leitura e escrita são enviadas ao dispositivo de armazenamento.
    > * O `mq-deadline` utiliza uma abordagem baseada em "deadlines" (prazos), vizando garantir que as requisições de I/O sejam atendidas dentro de um certo limite de tempo.&#x20;
    > * Ao priorizar as requisições que estão próximas de seu prazo, o `mq-deadline` evita que algumas tarefas fiquem indefinidamente esperando por acesso ao disco, proporcionando um desempenho mais consistente e previsível para todas as tarefas.
*   `autodefrag`, `space_cache`: no Btrfs, previne que arquivos virem farelo espalhado pelo disco.

    > * **O que fazem:** Estas são opções de montagem específicas para o sistema de arquivos Btrfs.
    >   * `autodefrag`: Ativa a desfragmentação automática dos arquivos em segundo plano enquanto o sistema está em uso.
    >     * Com o tempo, à medida que os arquivos são criados, modificados e excluídos, eles podem se tornar fragmentados, ou seja, seus pedaços ficam espalhados em diferentes locais do disco, diminuindo a velocidade de leitura desses arquivos.&#x20;
    >     * Essa flag tenta manter os arquivos contíguos (com seus pedaços lado a lado) para melhorar o desempenho da leitura.
    >   * `space_cache`: Habilita um cache para o mapa de alocação de espaço livre no disco.
    >     * Manter informações sobre os blocos livres do disco em um cache na memória acelera o processo de alocação de novos blocos quando arquivos são criados ou crescem.&#x20;
    >     * Sem o cache, o sistema precisaria percorrer o disco para encontrar espaço livre, o que seria mais lento.&#x20;

**Ganho real:** boot até 40% mais rápido, abertura de apps 20% mais rápida, IOPS (operações de leitura e escrita por segundo) aumentam em média 30%, especialmente sob carga mista.

#### 3. Sincronia com CPU (Uso Inteligente de Ciclos)

Sistema padrão trava a CPU com syscall inútil, processamento de journaling e I/O travado em filas burras. A CPU passa mais tempo esperando o disco do que processando o que importa.

Com as otimizações:

*   Compressão Zstd balanceada (`zstd:3`): usa entre 2% e 5% da CPU, mas reduz drasticamente o uso do SSD. Menos I/O físico significa mais tempo de CPU livre.

    > * Quando o sistema precisa ler ou escrever dados, a CPU precisa esperar que o SSD conclua a operação. Se o volume de dados a ser transferido é menor devido à compressão, o SSD leva menos tempo para realizar a operação.&#x20;
    > * Isso libera a CPU mais rapidamente para executar outras tarefas, resultando em mais tempo de CPU livre para o sistema e os aplicativos.
*   `crc32c-intel`: ativa instruções vetoriais específicas da arquitetura pra cálculo de checksum, reduzindo overhead.

    > * O CRC32c (Cyclic Redundancy Check) usa Checksums são usados para verificar a integridade dos dados, garantindo que não houve corrupção durante a transmissão ou armazenamento.
    > * As instruções vetoriais permitem que a CPU execute a mesma operação em múltiplos dados simultaneamente, em que, ao usar essas instruções dedicadas para o cálculo de checksums, a CPU realiza essa tarefa de forma muito mais eficiente, com menor consumo de recursos e, consequentemente, menor overhead (carga adicional sobre o processador).
*   OverlayFS combinado com SquashFS em diretórios de leitura pesada: sistema lê diretórios inteiros como se fossem imagens montadas na RAM, o que economiza syscall e maximiza cache de leitura.

    > * **O que fazem:**
    >   * **SquashFS:** É um sistema de arquivos compactado somente para leitura. Ele é usado para criar "imagens" compactadas de diretórios ou arquivos.
    >   * **OverlayFS:** É um sistema de arquivos que permite "sobrepor" dois diretórios (ou sistemas de arquivos). As modificações são gravadas em uma camada superior (gravável), enquanto a camada inferior (somente leitura) permanece intacta.
    > * Ao combinar SquashFS com OverlayFS, você pode criar uma imagem compactada (com SquashFS) de um diretório que é frequentemente lido, em que essa imagem pode ser montada como a camada inferior (somente leitura) do OverlayFS.&#x20;
    > * A camada superior do OverlayFS reside na RAM (ou em um local de escrita rápida), e quando o sistema precisa acessar um arquivo no diretório, ele primeiro verifica a camada superior.&#x20;
    > * Se o arquivo não estiver lá (o que é esperado para diretórios somente leitura), ele lê diretamente da imagem SquashFS que pode estar sendo mantida em cache na RAM pelo sistema operacional.
    > * **Por que economiza syscall e maximiza cache de leitura:**&#x20;
    >   * Montar um diretório inteiro como uma imagem na RAM reduz a necessidade de múltiplas chamadas ao sistema (syscalls) para acessar arquivos individuais.&#x20;
    >   * Em vez de abrir, ler e fechar vários arquivos separadamente, o sistema pode acessar os dados diretamente da imagem montada na RAM.&#x20;
    >   * Além disso, o SquashFS é projetado para ser altamente eficiente em termos de uso de espaço e também otimiza a leitura de dados compactados, maximizando a eficiência do cache de leitura da memória.
    >
    > #### **Pique como a nossa consciencia funcina, em que o corpo está aqui, mas a mente está em outro mundo.**
*   `lazytime`, `commit=120`: reduz número de syncs e fsyncs, que são assassinos silenciosos de tempo de CPU em qualquer sistema Unix-like.

    > * **O que fazem:**
    >   * **`lazytime`:** Adia a escrita de metadados relacionados aos tempos de acesso dos arquivos (atime, mtime, ctime) para o disco.&#x20;
    >     * Em vez de escrever esses metadados imediatamente quando um arquivo é acessado ou modificado, eles são escritos em momentos mais convenientes para o sistema (por exemplo, durante outras operações de escrita ou quando o sistema está ocioso).
    >   * **`commit=120`:** Para revizar, define um intervalo de 120 segundos para agrupar e escrever os metadados do sistema de arquivos.
    > * As operações `sync` e `fsync` forçam a escrita imediata dos dados e metadados pendentes no disco, e essas operações são importantes para garantir a integridade dos dados, mas podem ser custosas em termos de tempo de CPU e desempenho.&#x20;
    > * Ao adiar a escrita de metadados com `lazytime` e agrupar as escritas com um valor maior para `commit`, o número de operações `sync` e `fsync` necessárias para manter a consistência do sistema de arquivos é reduzido.
    > * As operações `sync` e `fsync` interrompem o fluxo normal de processamento, pois a CPU precisa esperar que a operação de escrita no disco seja concluída.&#x20;
    > * Em sistemas com muitas operações de escrita ou com aplicativos que realizam muitas chamadas `sync` ou `fsync`, o tempo gasto esperando pela conclusão dessas operações pode se acumular significativamente, consumindo tempo de CPU que poderia ser usado para outras tarefas.

**Ganho direto:** mais ciclos disponíveis pro que interessa. Menos tempo de espera. Processos pesados rodam com mais fluidez. A CPU deixa de ser secretária do SSD e volta a ser cérebro do sistema.

***

### Tabela de comparaão

| Critério                   | Instalação Padrão       | Configuração Otimizada       |
| -------------------------- | ----------------------- | ---------------------------- |
| Escritas por dia           | Alta                    | Redução de até 70%           |
| Vida útil do SSD           | \~3 anos em uso intenso | \~5-6 anos sem dor de cabeça |
| Tempo de boot              | 10-15 segundos          | 6-9 segundos                 |
| Abertura de aplicativos    | Lenta sob carga         | 15-30% mais rápida           |
| Utilização da CPU          | Cheia de I/O block      | Direcionada pra carga real   |
| Fragmentação               | Frequente               | Corrigida automaticamente    |
| Latência de disco          | Instável                | Previsível e otimizada       |
| Desempenho com multitarefa | Sofre                   | Mantém performance sob carga |

***
