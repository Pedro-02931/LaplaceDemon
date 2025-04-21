# Glossario Tecnico Explicado

## flush

**Sistema de arquivos:** vfat\
**O que faz:**\
Força a escrita imediata de dados no disco, desativando o cache de escrita sendo útil para sistemas de arquivos sem journaling, como o vfat, pois garante maior integridade, especialmente em ambientes sensíveis a falhas súbitas (como a partição EFI).

**Por que usar:**\
Evita inconsistências em partições onde a confiabilidade de boot é crucial, mesmo que isso afete performance.

***

## data=writeback

**Sistema de arquivos:** ext4\
**O que faz:**\
Permite que os dados do arquivo sejam gravados no disco antes do metadado. Isso reduz latência e melhora a performance, mas pode causar corrupção de metadados em caso de falha.

**Por que usar:**\
Útil em partições que não são críticas, como `/boot`, onde a prioridade é carregar o kernel rápido e não há escrita frequente.

***

## discard

**Aplicável a:** qualquer sistema em SSD\
**O que faz:**\
Ativa suporte ao comando TRIM, que informa ao SSD quais blocos estão livres. Isso melhora o desempenho de gravação futura e reduz o desgaste do disco.

**Por que usar:**\
Essencial para manter a performance e durabilidade de SSDs, garantindo que o sistema operacional se comunique com o controlador do disco de forma otimizada.

***

## btrfs(B-tree File System)

**O que é:**\
Um sistema de arquivos copy-on-write com suporte nativo a compressão, snapshots, verificação de integridade e RAID.

**Por que usar:**\
Permite compressão automática (`compress=zstd`), uso eficiente de espaço, e snapshots para restauração. Ideal para partições com uso dinâmico como `/root` e `/home`.

***

## space\_cache=v2

**Sistema de arquivos:** btrfs\
**O que faz:**\
Ativa a nova versão do cache de espaço interno do btrfs. Essa versão melhora a confiabilidade e performance na gestão de espaço livre.

**Por que usar:**\
Evita problemas de integridade e reduz o tempo de montagem do sistema de arquivos em discos maiores ou muito usados.

***

## barrier=0

**Sistema de arquivos:** ext4\
**O que faz:**\
Desativa as barreiras de escrita, que garantem a ordem correta de gravações entre o kernel e o disco. Desativar isso melhora a performance, mas pode resultar em perda de dados em caso de falha de energia.

**Por que usar:**\
Em partições como `/var`, onde performance de escrita é mais importante que integridade absoluta.

***

Perfeito, vamos continuar no mesmo ritmo técnico e direto. Seguem os próximos parâmetros:

***

## nodev

**Sistema de arquivos:** qualquer (normalmente em `/tmp`, `/dev/shm`)\
**O que faz:**\
Impede a criação ou execução de arquivos de dispositivo dentro do sistema de arquivos montado.

**Por que usar:**\
Aumenta a segurança em pontos de montagem temporários ou acessíveis por usuários, evitando exploits por criação de dispositivos maliciosos.

***

## nosuid

**Sistema de arquivos:** qualquer (também usado em `/tmp`, `/dev/shm`)\
**O que faz:**\
Desativa o bit SUID e SGID, ou seja, arquivos mesmo com permissão de root não podem escalar privilégios.

**Por que usar:**\
Evita que binários maliciosos com SUID obtenham privilégios elevados a partir de partições que não devem conter executáveis de confiança.

***

## noexec

**Sistema de arquivos:** geralmente usado em `/tmp`, `/var/tmp`\
**O que faz:**\
Impede a execução de qualquer binário presente nesse sistema de arquivos.

**Por que usar:**\
Reforça a segurança, especialmente em diretórios onde o usuário comum tem permissão de escrita.

***

## compress=zstd\[:nivel]

**Sistema de arquivos:** btrfs\
**O que faz:**\
Ativa compressão automática de arquivos. O algoritmo `zstd` oferece boa taxa de compressão com performance balanceada. O nível pode ir de 1 (rápido) até 19 (mais lento e mais compacto).

**Por que usar:**\
Reduz uso de espaço em disco e melhora performance em leitura/gravação para arquivos pequenos e repetitivos. Em SSDs, ajuda a diminuir o desgaste físico.

***

## autodefrag

**Sistema de arquivos:** btrfs\
**O que faz:**\
Ativa a desfragmentação automática em tempo de execução, especialmente útil para arquivos que mudam frequentemente.

**Por que usar:**\
Melhora performance de leitura e escrita contínua, especialmente em bancos de dados e perfis de usuário (`~/.cache`, por exemplo).

***

#### commit=120

**Sistema de arquivos:** ext4\
**O que faz:**\
Define o tempo em segundos entre commits de metadados no journal. O padrão é 5s. Um valor maior reduz a frequência de gravações.

**Por que usar:**\
Melhora a performance e reduz desgaste do SSD, mas aumenta a janela de risco de perda de metadados em falhas de energia.

***

Se quiser a próxima leva — por exemplo, os `pri=100`, `umask=0077`, ou a lógica dos `tmpfs` — posso seguir na sequência. Manda aí se tiver mais partes do artigo pra alinhar também.
