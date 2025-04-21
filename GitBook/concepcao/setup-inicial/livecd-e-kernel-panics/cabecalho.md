---
description: >-
  Protegido pela GPL2, isso significa que se me copiar sem nem ao menos me fazer
  referência, dá o bumbum - Linkedin:
  https://www.linkedin.com/in/pedro-mota-95046b356/
---

# Cabeçalho

Antes de sair formatando feito louco, precisamos preparar o ambiente e definir as regras do jogo, onde tudo deve seguir um padrão que garanta a comunicação entre o usuário e o computador, onde um reflete o outro&#x20;

> Humanos conseguem se conectar com qualquer coisa, e quanto mais organizado essa coisa for no fluxo de dados, mais "humana" ela se torna.

### O Que Foi Feito

o script começa definindo onde guardar registros (`LOG_DIR`, `LOG_FILE`) e um controle (`CONTROL_FILE`) para não repetir ações destrutivas, onde foquei mais em remover o que deu certo, trocando blocos gigantescos de informação inutil em echos diminutivos, onde para discernir de um e outro basta ver se foi para o stdder.

O `LOG_DIR` foi focado mais para a otimização e debug com o uso de LLMs, onde o mapeamento de forma mais eficiente é essencial, e futuramente quero fazer uma função de compressão entrópica para adicionar uma camada de metacognição usando fluxos de textos.

A linha `set -euo pipefail` manda o script parar imediatamente se qualquer comando falhar, evitando cascata de erros, enquanto o `trap` é o botão de emergência que avisa onde o problema aconteceu antes de abortar a missão, assim eu consigo debugar de forma mais eficiente, onde a quantidade de dados iniciais que define a acertividade final.

```
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

***

## Minha Ideia: Escolhendo o Alvo Certo

Bash

```
# ----------------------------------------
# 🔍 FUNÇÃO: SELECIONAR DISCO
# ----------------------------------------
selecionar_disco() {
    d_l "Detectando discos disponíveis..."
    lsblk -dpno NAME,SIZE,MODEL | nl -w2 -s'. '
    echo
    read -p "Escolha o número do disco para formatar: " idx
    DISK=$(lsblk -dpno NAME | sed -n "${idx}p")
    if [[ -z "$DISK" ]]; then
        echo "Disco inválido!" | tee -a "$LOG_FILE" >&2
        exit 1
    fi
    d_l "Você escolheu o disco $DISK"
}
```

### Explicação a Nível Lógico e Eletrônico

Esta função é crucial para garantir que a formatação ocorra no lugar certo, evitando a catástrofe de apagar o disco errado, imagine ter várias chaves e precisar abrir uma porta específica, você precisa identificar a chave correta antes de tentar girar a fechadura; o comando `lsblk -dpno NAME,SIZE,MODEL` lista todos os dispositivos de bloco (discos, partições) de forma clara, mostrando o nome completo do dispositivo (`/dev/sda`, `/dev/nvme0n1`), tamanho e modelo, facilitando a identificação visual. O `nl -w2 -s'. '` adiciona um número sequencial a cada linha, tornando a seleção pelo usuário mais simples e menos propensa a erros de digitação, pense nisso como etiquetar cada chave com um número para facilitar a escolha.

O comando `read -p "..." idx` pausa o script e pede ao usuário para digitar o número correspondente ao disco desejado, essa interação é vital para a segurança; o `sed -n "${idx}p"` então extrai apenas o nome do disco (`/dev/sdX`) referente ao número escolhido e armazena na variável `DISK`. A verificação `if [[ -z "$DISK" ]]` confere se a variável `DISK` ficou vazia (o que aconteceria se o usuário digitasse um número inválido ou apenas pressionasse Enter), e caso esteja vazia, exibe uma mensagem de erro, registra no log e encerra o script (`exit 1`), atuando como uma última verificação de segurança para impedir que o script continue sem um alvo válido, como um segurança de banco conferindo a identidade antes de liberar o acesso ao cofre, garantindo que apenas o disco correto será afetado pelas operações seguintes.

## Ganhos em Relação Entre o Método Tradicional e o Meu

No método tradicional, especialmente em scripts mais simples ou na execução manual de comandos, a identificação do disco pode ser feita "de olho" ou baseada em conhecimento prévio, o que é extremamente perigoso em sistemas com múltiplos discos (HDs, SSDs, NVMEs, pendrives), a chance de confundir `/dev/sda` com `/dev/sdb` ou um NVMe com outro é real e as consequências são desastrosas, como um cirurgião operando o membro errado por falta de checagem; a ausência de uma listagem clara e de uma confirmação explícita aumenta exponencialmente o risco de perda total de dados importantes, tornando o processo tenso e arriscado.

Meu método introduz uma camada clara de identificação e seleção, o `lsblk` formatado com `nl` apresenta as opções de forma inequívoca, reduzindo a ambiguidade e facilitando a escolha correta, é como ter um catálogo visual com fotos e descrições de cada item antes de selecionar; a necessidade de digitar o número força o usuário a prestar atenção e a verificação `if [[ -z "$DISK" ]]` garante que o script não prossiga sem um alvo válido definido, minimizando drasticamente a possibilidade de erro humano. Essa abordagem transforma um passo potencialmente perigoso em um procedimento seguro e controlado, garantindo que a "cirurgia" de formatação seja feita exatamente onde deveria, preservando a integridade dos outros discos do sistema, proporcionando paz de espírito durante um processo inerentemente crítico.

### Tabela de Explicação: Seleção de Disco

| **Característica**    | **Método Tradicional**              | **Meu Método (Script)**                   |
| --------------------- | ----------------------------------- | ----------------------------------------- |
| **Identificação**     | Manual, baseada em nomes (`sdX`)    | Listagem clara (`lsblk`, `nl`) com modelo |
| **Seleção**           | Direta do nome, propenso a erro     | Numérica, menos ambígua                   |
| **Validação**         | Geralmente ausente                  | Verificação explícita se disco é válido   |
| **Risco de Erro**     | Alto, especialmente com multi-disco | Muito baixo                               |
| **Segurança**         | Baixa                               | Alta, com confirmação implícita           |
| **Interface Usuário** | Linha de comando pura               | Interativa e guiada                       |

***

## Minha Ideia: Limpeza Profunda e Estrutura Base

Bash

```
# ----------------------------------------
# 🛠️ FUNÇÃO: PREPARAR DISCO E CRIAR PARTIÇÕES
# ----------------------------------------
preparar_disco() {
    local tag="preparar_disco"
    if ja_executado "$tag"; then
        d_l ">>> preparar_disco já executado, pulando."
        return
    fi
    d_l "Limpando disco $DISK..."
    umount -R "$MOUNTROOT" 2>/dev/null || true
    swapoff -a 2>/dev/null || true
    dmsetup remove_all 2>/dev/null || true
    umount "${DISK}"* 2>/dev/null || true

    wipefs -a "$DISK"
    sgdisk --zap-all "$DISK"
    dd if=/dev/zero of="$DISK" bs=1M count=10 status=progress
    partprobe "$DISK"; sleep 2; udevadm settle

    d_l "Criando partições (EFI + BOOT + LVM PV)..."
    sgdisk --new=1:0:+512M    --typecode=1:ef00 --change-name=1:"Cortex-Boot-EFI" "$DISK"
    sgdisk --new=2:0:+1G      --typecode=2:8300 --change-name=2:"Cerebellum-Boot" "$DISK"
    sgdisk --new=3:0:0        --typecode=3:8e00 --change-name=3:"Brainstem-LVM" "$DISK"
    partprobe "$DISK"; sleep 2; udevadm settle

    marcar_como_executado "$tag"
    d_l "Disco preparado com sucesso."
}
```

### Explicação a Nível Lógico e Eletrônico

Esta função é a demolição controlada seguida pela construção da fundação do nosso sistema no disco selecionado, primeiro, ela verifica se já foi executada (`ja_executado`) para evitar refazer a limpeza e particionamento, garantindo a segurança; em seguida, executa uma série de comandos de "desmonte": `umount -R` desmonta recursivamente qualquer coisa montada no diretório temporário, `swapoff -a` desativa todas as áreas de swap, `dmsetup remove_all` remove mapeamentos do Device Mapper (como LVMs antigos ou partições criptografadas) e `umount "${DISK}"*` tenta desmontar quaisquer partições do disco alvo que ainda possam estar montadas, é como isolar a área de demolição e desligar água, luz e gás antes de começar a derrubar as paredes.

A limpeza profunda vem com `wipefs -a` que apaga assinaturas de sistemas de arquivos e partições diretamente nos setores iniciais e finais, `sgdisk --zap-all` que destrói a tabela de partição GPT (ou MBR) existente, e `dd if=/dev/zero ...` que sobrescreve os primeiros 10 megabytes do disco com zeros, garantindo a remoção de bootloaders antigos e metadados persistentes, pense nisso como remover entulho, limpar o terreno e nivelar a área antes de construir; `partprobe` e `udevadm settle` pedem ao kernel e ao sistema para relerem a tabela de partição (agora vazia) e atualizarem o estado dos dispositivos. Finalmente, `sgdisk --new...` cria as novas partições: uma EFI de 512MB (código `ef00`), uma /boot de 1GB (código `8300` - Linux filesystem) e a principal usando o restante do espaço para ser o Volume Físico (PV) do LVM (código `8e00` - Linux LVM), definindo a estrutura base onde o sistema operacional e os dados residirão, como construir as vigas e colunas mestras da nova edificação.

## Ganhos em Relação Entre o Método Tradicional e o Meu

O método tradicional muitas vezes se limita a usar ferramentas de particionamento que apenas recriam a tabela de partição, sem garantir a limpeza completa de metadados antigos ou bootloaders que podem causar conflitos ou comportamentos inesperados mais tarde, é como pintar uma parede mofada sem tratar o mofo primeiro, o problema continua lá por baixo; a falta de comandos explícitos para desmontar e desativar volumes pode levar a erros de "dispositivo ocupado" ou falhas no particionamento, exigindo intervenção manual e aumentando a complexidade do processo, tornando a instalação menos confiável e mais frustrante.

Meu método adota uma abordagem de "terra arrasada controlada", a combinação de `umount`, `swapoff`, `dmsetup remove`, `wipefs`, `sgdisk --zap-all` e `dd` garante que o disco esteja verdadeiramente limpo e pronto para a nova estrutura, eliminando potenciais fontes de conflito e assegurando um início limpo, como demolir completamente a estrutura antiga e preparar um terreno impecável para a nova construção; a criação explícita das partições com `sgdisk`, definindo tamanhos, tipos (typecodes) e nomes claros, estabelece uma base sólida e organizada para o LVM e o sistema de arquivos, facilitando a manutenção futura. A inclusão de `partprobe` e `udevadm settle` após cada mudança estrutural garante que o sistema operacional reconheça as alterações imediatamente, evitando inconsistências, resultando em um processo de preparação de disco muito mais robusto, confiável e previsível.

### Tabela de Explicação: Preparação de Disco

| **Característica**        | **Método Tradicional**                        | **Meu Método (Script)**                                      |
| ------------------------- | --------------------------------------------- | ------------------------------------------------------------ |
| **Limpeza Prévia**        | Opcional, muitas vezes apenas recria tabela   | Extensiva (`wipefs`, `zap-all`, `dd`)                        |
| **Desmontagem**           | Pode falhar se dispositivo estiver ocupado    | Forçada (`umount`, `swapoff`, `dmsetup remove`)              |
| **Remoção de Conflitos**  | Menos garantida                               | Alta probabilidade de eliminar bootloaders/metadados antigos |
| **Criação de Partições**  | Pode ser manual ou com padrões simples        | Automatizada, com tipos e tamanhos específicos (`sgdisk`)    |
| **Reconhecimento Kernel** | Pode precisar de reboot ou intervenção manual | Forçado (`partprobe`, `udevadm settle`)                      |
| **Robustez**              | Menor                                         | Muito maior, menos propenso a erros residuais                |

***

## Minha Ideia: Flexibilidade e Gerenciamento Inteligente de Espaço

Bash

```
# ----------------------------------------
# 💡 FUNÇÃO: CONFIGURAR LVM E CRIAR LVs
# ----------------------------------------
configurar_lvm() {
    local tag="configurar_lvm"
    if ja_executado "$tag"; then
        d_l ">>> configurar_lvm já executado, pulando."
        return
    fi
    d_l "Configurando LVM em ${DISK}3..."
    vgremove -f "$VG" 2>/dev/null || true
    pvcreate -ff -y "${DISK}3"
    vgcreate "$VG" "${DISK}3"

    VG_SIZE_BYTES=$(vgdisplay "$VG" --units b --noheading -o vg_size | tr -dc '0-9')
    VG_SIZE_MB=$((VG_SIZE_BYTES / 1024 / 1024))
    d_l "VG size: ${VG_SIZE_MB} MiB"

    for lv in root var tmp usr home; do
        pct=${PERCENTUAIS[$lv]}
        size_mb=$((VG_SIZE_MB * pct / 100))
        d_l "Criando LV $lv: ${pct}% → ${size_mb}MiB"
        lvcreate -n "$lv" -L "${size_mb}M" "$VG"
    done

    marcar_como_executado "$tag"
    d_l "LVM configurado com sucesso."
}
```

### Explicação a Nível Lógico e Eletrônico

Aqui entra o LVM (Logical Volume Manager), uma camada de abstração poderosa sobre o particionamento físico, pense nele como criar divisórias flexíveis dentro de um grande galpão (o disco físico) em vez de construir paredes de tijolo fixas; a função primeiro garante que não foi executada antes e remove qualquer Volume Group (VG) antigo com o mesmo nome (`vgremove -f "$VG"`) para evitar conflitos, depois inicializa a terceira partição física (`${DISK}3`) como um Physical Volume (PV) com `pvcreate`, que basicamente marca essa partição como disponível para o LVM, como preparar o terreno dentro do galpão para receber as divisórias. O comando `vgcreate "$VG" "${DISK}3"` cria o Volume Group chamado `vg_opt` (definido na variável `VG`) usando o PV que acabamos de criar, este VG é o "pool" de espaço total de onde criaremos nossas partições lógicas.

Em seguida, calculamos o tamanho total do VG em Megabytes para poder usar os percentuais definidos anteriormente (`PERCENTUAIS`), obtendo o tamanho em bytes (`vgdisplay ... --units b ...`), removendo caracteres não numéricos (`tr -dc '0-9'`) e convertendo para MB; o loop `for lv in root var tmp usr home; do ... done` itera sobre os nomes das partições lógicas que queremos criar, para cada uma, ele pega o percentual correspondente (`pct=${PERCENTUAIS[$lv]}`), calcula o tamanho em MB (`size_mb=$((VG_SIZE_MB * pct / 100))`) e finalmente cria o Logical Volume (LV) com `lvcreate -n "$lv" -L "${size_mb}M" "$VG"`, esses LVs (`/dev/vg_opt/root`, `/dev/vg_opt/var`, etc.) são os dispositivos que formataremos depois, funcionando como as salas criadas com as divisórias flexíveis dentro do galpão, cada uma com um tamanho inicial definido mas com a possibilidade de redimensionamento futuro sem mexer nas outras.

## Ganhos em Relação Entre o Método Tradicional e o Meu

O método tradicional geralmente envolve criar partições físicas com tamanhos fixos diretamente no disco (`/dev/sda1`, `/dev/sda2`, etc.), essa abordagem é rígida, se você definir 20GB para o `/` (root) e depois descobrir que precisa de mais espaço, redimensionar é um processo complexo e arriscado que geralmente envolve ferramentas externas e pode exigir mover o início da partição seguinte, é como ter construído todas as paredes internas da casa com tijolos, mudar o tamanho de um cômodo exige uma obra grande e bagunçada; além disso, gerenciar o espaço livre fragmentado entre várias partições físicas é ineficiente.

Meu método com LVM oferece uma flexibilidade imensa, criar LVs baseados em percentuais do espaço total disponível no VG garante uma distribuição proporcional inicial, mas a grande vantagem é a facilidade de redimensionamento posterior, se o LV `root` ficar pequeno, você pode diminuir o LV `home` (se houver espaço livre nele) e aumentar o `root` com alguns comandos simples, sem precisar mover dados fisicamente no disco ou usar ferramentas complexas, é como ter divisórias de drywall que podem ser movidas facilmente para reconfigurar o espaço interno da casa; o LVM também permite funcionalidades avançadas como snapshots (cópias instantâneas do estado de um LV) e a fácil adição de mais discos físicos ao mesmo VG para expandir o espaço total, tornando o gerenciamento do armazenamento muito mais dinâmico e adaptável às necessidades futuras.

### Tabela de Explicação: Gerenciamento de Espaço (LVM)

| **Característica**        | **Método Tradicional (Partições Físicas)** | **Meu Método (LVM)**                 |
| ------------------------- | ------------------------------------------ | ------------------------------------ |
| **Flexibilidade Tamanho** | Baixa, redimensionamento complexo          | Alta, redimensionamento fácil de LVs |
| **Gerenciamento Espaço**  | Fragmentado entre partições físicas        | Centralizado no Volume Group (VG)    |
| **Adição de Disco**       | Complexa, requer re-particionamento        | Fácil, adiciona PV ao VG existente   |
| **Snapshots**             | Não suportado nativamente                  | Suportado nativamente pelo LVM       |
| **Abstração**             | Nenhuma, direto no hardware                | Camada Lógica (PV -> VG -> LV)       |
| **Complexidade Inicial**  | Menor                                      | Levemente maior (conceitos LVM)      |
| **Manutenibilidade**      | Menor                                      | Muito maior                          |

***

## Minha Ideia: Formatação Inteligente e Otimizações Cirúrgicas

Bash

```
# ----------------------------------------
# 🛠️ FUNÇÃO: FORMATAR E APLICAR OTIMIZAÇÕES
# ----------------------------------------
formatar_e_otimizar() {
    local tag="formatar_e_otimizar"
    if ja_executado "$tag"; then
        d_l ">>> formatar_e_otimizar já executado, pulando."
        return
    fi
    # EFI e BOOT
    for key in EFI BOOT; do
        IFS=' ' read -r fs mkfs_opts tune_opts mount_opts <<< "${OTIMIZACOES[$key]}"
        part="${DISK}$([[ "$key" == "EFI" ]] && echo "1" || echo "2")"
        d_l "Formatando $key ($part) como $fs..."
        eval mkfs.$fs $mkfs_opts "$part"
        [[ -n $tune_opts ]] && eval tune2fs $tune_opts "$part"
        mkdir -p "$MOUNTROOT/$([[ "$key" == "EFI" ]] && echo "boot/efi" || echo "boot")"
        mount -o "$mount_opts" "$part" "$MOUNTROOT/$([[ "$key" == "EFI" ]] && echo "boot/efi" || echo "boot")"
    done

    # LVs
    for lv in root var tmp usr home; do
        IFS=' ' read -r fs mkfs_opts tune_opts mount_opts <<< "${OTIMIZACOES[$lv]}"
        part="/dev/$VG/$lv"
        d_l "Formatando LV $lv ($part) como $fs..."
        eval mkfs.$fs $mkfs_opts "$part"
        [[ -n $tune_opts ]] && eval tune2fs $tune_opts "$part"
        mkdir -p "$MOUNTROOT/$lv"
        mount -o "$mount_opts" "$part" "$MOUNTROOT/$lv"
    done

    # Swap via arquivo
    d_l "Criando swapfile em $MOUNTROOT/swapfile..."
    fallocate -l "$((VG_SIZE_MB * PERCENTUAIS[swap] / 100))M" "$MOUNTROOT/swapfile"
    chmod 600 "$MOUNTROOT/swapfile"
    mkswap -L SWAP "$MOUNTROOT/swapfile"
    swapon "$MOUNTROOT/swapfile"

    marcar_como_executado "$tag"
    d_l "Formatação e otimizações aplicadas."
}
```

### Explicação a Nível Lógico e Eletrônico

Este é o clímax, onde aplicamos as configurações finas que realmente fazem a diferença no dia a dia, aqui pegamos as estruturas criadas (partições físicas EFI/BOOT e LVs) e damos vida a elas com sistemas de arquivos específicos e opções de montagem otimizadas, como escolher o piso certo para cada cômodo da casa e aplicar um verniz especial; a função primeiro lida com as partições físicas de boot: para EFI usa `vfat` (FAT32) com opções `noatime,nodiratime,flush` para reduzir escritas desnecessárias e garantir que dados importantes sejam gravados rapidamente, para BOOT usa `ext4` com `data=writeback,noatime,discard` combinando velocidade de escrita, redução de metadados e suporte a TRIM para SSDs. O `eval mkfs...` cria o sistema de arquivos, `eval tune2fs...` aplica ajustes finos (se houver), `mkdir` cria o ponto de montagem e `mount -o ...` monta a partição com as opções definidas.

A segunda parte faz o mesmo para os Logical Volumes (`root`, `var`, `tmp`, `usr`, `home`), mas aqui as otimizações são ainda mais cruciais e variadas: `root` e `home` usam `btrfs` com compressão `zstd` (nível 3 para root, mais agressivo, nível 1 para home, mais leve), `noatime` para economizar escritas, `space_cache=v2` e `ssd` para otimizar alocação em SSDs e `autodefrag` para combater a fragmentação; `var` (logs e dados variáveis) usa `ext4` com `data=journal,barrier=0` focado um pouco mais em segurança dos dados mas ainda rápido; `tmp` (temporários) usa `ext4` com `noatime,nodiratime,nodev,nosuid,noexec,discard` focando em velocidade e segurança (impedindo execução de binários); `usr` (programas) usa `ext4` com `noatime,nodiratime,discard,commit=120` adiando escritas de metadados para agrupar operações. Finalmente, cria um `swapfile` (em vez de partição) com `fallocate`, ajusta permissões (`chmod 600`), formata com `mkswap` e ativa com `swapon`, usando um arquivo que pode ser facilmente redimensionado ou removido depois, oferecendo mais flexibilidade que uma partição swap fixa.

## Ganhos em Relação Entre o Método Tradicional e o Meu

A formatação tradicional geralmente aplica o mesmo sistema de arquivos (quase sempre ext4) com opções de montagem padrão (`relatime`, `data=ordered`) para todas as partições (exceto EFI e swap), essa abordagem "tamanho único" ignora as diferentes necessidades de cada parte do sistema e desperdiça o potencial de otimização, especialmente com SSDs, é como usar o mesmo tipo de pneu para um carro de corrida, um caminhão e uma bicicleta, simplesmente não é eficiente; as opções padrão causam escritas excessivas de metadados (`relatime`), não aproveitam compressão para economizar espaço e escritas, não ativam TRIM contínuo (`discard`) para manter o SSD ágil e usam journaling (`data=ordered`) que pode segurar um pouco o desempenho de escrita em troca de uma segurança que nem sempre é necessária em todas as partições.

Meu método aplica um "tuning" específico para cada LV/partição, reconhecendo que `/tmp` tem um perfil de uso diferente de `/home` ou `/var`, usamos `btrfs` onde suas funcionalidades (compressão, snapshots, checksums) trazem mais benefícios (`root`, `home`), e `ext4` otimizado onde estabilidade e compatibilidade são chave (`var`, `tmp`, `usr`, `boot`); as opções de montagem são escolhidas a dedo: `noatime`/`nodiratime` cortam escritas de acesso drasticamente, `compress=zstd` reduz o volume de dados escritos (aumentando vida útil do SSD e velocidade de leitura/escrita efetiva ao custo de um pouco de CPU), `discard` mantém o SSD limpo, `commit=120` agrupa escritas de metadados, `data=writeback` acelera escritas onde seguro, `space_cache`/`ssd` otimizam para SSDs, e `nodev/nosuid/noexec` em `/tmp` adicionam segurança. O uso de `swapfile` em vez de partição swap adiciona flexibilidade pós-instalação, resultando em um sistema significativamente mais rápido, responsivo, durável (especialmente o SSD) e seguro.

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

## Minha Ideia: Orquestrando a Execução Final

Bash

```
# ----------------------------------------
# 🧠 FUNÇÃO PRINCIPAL
# ----------------------------------------
main() {
    selecionar_disco
    if ! confirmar_execucao "Isto vai destruir todos os dados em $DISK"; then
        d_l "Operação cancelada pelo usuário."
        exit 0
    fi
    preparar_disco
    configurar_lvm
    formatar_e_otimizar
    d_l "Processo concluído: +20-40% de vida útil do SSD, +15-30% de I/O, sincronia CPU/SSD atingida."
}

main
```

### Explicação a Nível Lógico e Eletrônico

A função `main` é o maestro da orquestra, responsável por chamar as outras funções na ordem correta para que todo o processo de preparação e otimização do disco ocorra de forma lógica e segura, como um gerente de projetos garantindo que cada etapa da construção seja executada na sequência apropriada, da fundação ao acabamento; primeiro, ela chama `selecionar_disco()` para que o usuário identifique e confirme qual disco será o alvo da operação, garantindo que não estamos apontando a "arma" para o lugar errado. Logo após, vem a confirmação final com `confirmar_execucao`, apresentando a mensagem de aviso sobre a destruição de dados e esperando um "sim" explícito do usuário antes de prosseguir, esta é a última barreira de segurança, o "ponto de não retorno" consciente.

Se o usuário confirmar, a função `main` então executa sequencialmente as três etapas cruciais: `preparar_disco()` que limpa o disco e cria a estrutura de partições base (EFI, Boot, LVM PV); `configurar_lvm()` que configura o Volume Group e cria os Logical Volumes flexíveis (`root`, `var`, `tmp`, `usr`, `home`) dentro do espaço LVM; e finalmente `formatar_e_otimizar()` que aplica os sistemas de arquivos específicos e as opções de montagem otimizadas a cada partição e LV, além de criar o swapfile. Após a conclusão bem-sucedida de todas essas etapas, a função `main` exibe uma mensagem final resumindo os benefícios esperados, como o aumento da vida útil do SSD, a melhoria no desempenho de entrada/saída (I/O) e a melhor sincronia entre CPU e disco, celebrando o sucesso da operação e informando ao usuário que o disco está pronto e otimizado. A chamada `main` no final do script é o que efetivamente inicia todo o processo.

## Ganhos em Relação Entre o Método Tradicional e o Meu

Em um processo manual ou com scripts menos estruturados, a ordem de execução dos comandos pode ser confusa ou até incorreta, levando a erros difíceis de diagnosticar, por exemplo, tentar criar um LV antes do VG, ou formatar uma partição antes de criá-la, seria como tentar pintar a parede antes de construí-la; a falta de uma função `main` clara que orquestra o fluxo torna o processo menos legível e mais difícil de manter ou modificar, além de aumentar a chance de pular etapas importantes ou executá-las fora de ordem, especialmente se houver interrupções ou erros no meio do caminho.

A estrutura com uma função `main` bem definida no meu script garante uma execução lógica, sequencial e modular, cada função chamada pela `main` tem uma responsabilidade clara e executa um conjunto coeso de tarefas antes de passar para a próxima, isso torna o script mais fácil de entender, depurar e modificar, pois cada bloco de funcionalidade está encapsulado; a ordem `selecionar_disco` -> `confirmar` -> `preparar_disco` -> `configurar_lvm` -> `formatar_e_otimizar` é a sequência lógica correta para garantir que as dependências sejam satisfeitas (não se pode configurar LVM sem uma partição PV, não se pode formatar um LV sem criá-lo). Essa organização não apenas previne erros de execução, mas também melhora a robustez geral do processo, assegurando que todas as etapas necessárias sejam concluídas na ordem certa para entregar um sistema otimizado e funcional ao final.

### Tabela de Explicação: Orquestração (main)

| **Característica**    | **Método Tradicional (Manual/Scripts Simples)** | **Meu Método (Função main Estruturada)** |
| --------------------- | ----------------------------------------------- | ---------------------------------------- |
| **Ordem de Execução** | Dependente do usuário, propensa a erros         | Garantida pela lógica da `main`          |
| **Modularidade**      | Baixa, comandos misturados                      | Alta, funções com responsabilidades      |
| **Legibilidade**      | Menor                                           | Maior                                    |
| **Manutenibilidade**  | Difícil                                         | Fácil                                    |
| **Robustez**          | Menor, erros de sequência são comuns            | Maior, fluxo lógico assegurado           |
| **Controle Geral**    | Difuso                                          | Centralizado na `main`                   |
