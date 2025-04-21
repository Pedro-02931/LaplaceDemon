# Configurações Globais

Aqui foi onde o meu script brilha, que foi a implementação de um conceito que inventei na base da gambiarra que é a memoria cruzada, em que através da criação de um valor discriminante na chave, consigo carregar palavras chaves de colapsos, e através de laços for loop, consigo executar compressão entrópica.

Assim, usado o conceito de bayes onde o laço for é o observador e o array é o campo latente mapeado, ele garante a execução com base no estado medido. Também decididi  usar valores percentuais para garantir a universalidade de quando eu rodar esse script quando troca de computador. O restante a memoria é destinado para o home, assim garantindo o uso completo do ssd com uma distribuição inteigente.

> `["EFI"]="vfat "-F32 -n EFI" "" noatime,nodiratime,flush"`
>
> * `vfat`: a linguagem dos ancestrais — universal, simples, reconhecida até por entidades obscuras lovecraftanas.
> * `-F32 -n EFI`: define a estrutura como FAT32 e nomeia.
> * `noatime,nodiratime`: elimina escrita de metadados desnecessários
> * `flush`: Força sincronização de buffers após escrita. Mais segura, mas mais lenta: escreve direto no disco
>
> `["BOOT"]="ext4 "-q -L BOOT" "" data=writeback,noatime,discard"`
>
> * `ext4`: filesystem de confiança, equilibrado entre legado e potência, sendo muito usado no Linux.
> * `data=writeback`: escrita preguiçosa, onde os dados são escritos antes do journaling (equivalente a pensar).
> * `discard`: Informa ao SSD quais blocos não são mais usados, funcionando como gatilho para o comando TRIM via hardware
>
> `["root"]="btrfs "-L ROOT -f" "" compress=zstd:3,noatime,space_cache=v2,ssd,autodefrag"`
>
> * `btrfs`: Sistema copy-on-write, suporta compressão e snapshots. Dinâmico, moderno, pode fragmentar sem autodefrag
> * `compress=zstd:3`: compressão entrópica moderada, mantendo equilíbrio entre espaço e performance.
> * `space_cache=v2`: Cache de espaço livre otimizado, em que necessita de menos consulta no disco para alocação
> * `autodefrag`: Fragmentação corrigida dinamicamente reordenando blocos com base em acesso real
> * `ssd`: Ativa heurísticas otimizadas para SSD reduzindo desgaste, melhora TRIM e flushing
>
> `["var"]="ext4 "-q -L VAR" "-o journal_data_writeback" data=journal,barrier=0"`&#x20;
>
> * `journal_data_writeback`: Usa journal, mas não sincroniza dados gravando posteriormente, aumentando a performance
> * `data=journal`: Primeiro grava dados no journal, depois no local final, onde é mais seguro, porém mais uso de I/O
> * `barrier=0`:  Desliga garantias de ordem via cache de disco , e embora tenha risco em power loss, há  ganho de performance
>
> `["tmp"]="ext4 "-q -L TMP" "" noatime,nodiratime,nodev,nosuid,noexec,discard"`
>
> * Tudo já explicado
>
> `["usr"]="ext4 "-q -L USR" "" noatime,nodiratime,discard,commit=120"`
>
> * `commit=120`: escreve de tempos em tempos — eficiência acima de tudo, mesmo que implique esquecer algo em caso de falha.
>
> `["home"]="btrfs "-L HOME -f" "" compress=zstd:1,autodefrag,noatime,space_cache=v2,ssd"`
>
> * Já explicado
>
> `["swap"]="swap "-L SWAP" "" discard,pri=100"`
>
> * `pri=100`: alta prioridade — pronto para agir quando a RAM falhar.

{% code overflow="wrap" %}
```bash
VG="vg_opt"
MOUNTROOT="/mnt"

declare -A PERCENTUAIS=(
    [root]=20
    [var]=5
    [tmp]=2
    [usr]=25
)
TOTAL_PCT=0
for pct in "${PERCENTUAIS[@]}"; do
    TOTAL_PCT=$((TOTAL_PCT + pct))
done
PERCENTUAIS[home]=$((100 - TOTAL_PCT))
PERCENTUAIS[swap]=5

declare -A MEMORIA_CRUZADA=(
    ["EFI"]="vfat \"-F32 -n EFI\" \"\" noatime,nodiratime,flush"
    ["BOOT"]="ext4 \"-q -L BOOT\" \"\" data=writeback,noatime,discard"
    ["root"]="btrfs \"-L ROOT -f\" \"\" compress=zstd:3,noatime,space_cache=v2,ssd,autodefrag"
    ["var"]="ext4 \"-q -L VAR\" \"-o journal_data_writeback\" data=journal,barrier=0"
    ["tmp"]="ext4 \"-q -L TMP\" \"\" noatime,nodiratime,nodev,nosuid,noexec,discard"
    ["usr"]="ext4 \"-q -L USR\" \"\" noatime,nodiratime,discard,commit=120"
    ["home"]="btrfs \"-L HOME -f\" \"\" compress=zstd:1,autodefrag,noatime,space_cache=v2,ssd"
    ["swap"]="swap \"-L SWAP\" \"\" discard,pri=100"
)
```
{% endcode %}



