# Configurações Globais

Aqui foi onde o meu script brilha, que foi a implementação de um conceito que inventei na base da gambiarra que é a memoria cruzada, em que através da criação de um valor discriminante na chave, consigo carregar palavras chaves de colapsos, e através de laços for loop, consigo executar compressão entrópica.

Assim, usado o conceito de bayes onde o laço for é o observador e o array é o campo latente mapeado, ele garante a execução com base no estado medido. Também decididi  usar valores percentuais para garantir a universalidade de quando eu rodar esse script quando troca de computador. O restante a memoria é destinado para o home, assim garantindo o uso completo do ssd com uma distribuição inteigente.

> `["EFI"]="vfat "-F32 -n EFI" "" noatime,nodiratime,flush"`
>
> * `vfat`: a linguagem dos ancestrais — universal, simples, reconhecida até por entidades obscuras lovecraftanas.
> * `-F32 -n EFI`: define a estrutura como FAT32 e nomeia.
> * `noatime,nodiratime`: elimina ruído temporal evitando a escrita de metadados para cada acesso.
> * `flush`: sincronia total, em que cada ação é gravada como promessa cumprida, sem cache, sem delay.
>
> `["BOOT"]="ext4 "-q -L BOOT" "" data=writeback,noatime,discard"`
>
> * `ext4`: filesystem de confiança, equilibrado entre legado e potência, sendo muito usado no Linux.
> * `data=writeback`: escrita preguiçosa.
> * `noatime`: evita registro de acessos triviais.
> * `discard`: joga fora o que não serve, permitido por integração com SSD.
>
> `["root"]="btrfs "-L ROOT -f" "" compress=zstd:3,noatime,space_cache=v2,ssd,autodefrag"`
>
> * `btrfs`: suporta snapshots, compressão, e resiliência.
> * `compress=zstd:3`: compressão entrópica moderada, mantendo equilíbrio entre espaço e performance.
> * `space_cache=v2`: melhora a alocação no tempo-espaço.
> * `autodefrag`: reorganiza fragmentos.
> * `ssd`: ativa o modo de operação de velocidade
>
> `["var"]="ext4 "-q -L VAR" "-o journal_data_writeback" data=journal,barrier=0"`&#x20;
>
> * `journal_data_writeback`: não espera para escrever no jounal
> * `data=journal`: mas ainda mantém um diário — toda escrita é registrada primeiro, confiável.
> * `barrier=0`:  menos seguro, mas mais ágil.
>
> `["tmp"]="ext4 "-q -L TMP" "" noatime,nodiratime,nodev,nosuid,noexec,discard"`
>
> * `nodev,nosuid,noexec`: anada executa, nada assume identidade, tudo é efêmero, cumprindo objetivo tmp
> * `discard`: lixo levado com o vento.
> * `noatime,nodiratime`: não perde tempo lembrando do que é descartável.
>
> `["usr"]="ext4 "-q -L USR" "" noatime,nodiratime,discard,commit=120"`
>
> * `commit=120`: escreve de tempos em tempos — eficiência acima de tudo, mesmo que implique esquecer algo em caso de falha.
> * `discard`: remove vestígios residuais — SSD agradece.
> * `noatime,nodiratime`: leitura silencios
>
> `["home"]="btrfs "-L HOME -f" "" compress=zstd:1,autodefrag,noatime,space_cache=v2,ssd"`
>
> * `compress=zstd:1`: compressão leve — valoriza a performance sem abrir mão da organização.
> * `autodefrag`: adapta-se conforme os hábitos mudam.
> * `noatime`: não julga o que é aberto.
> * `space_cache`, `ssd`: garante que a experiência seja suave e responsiva.
>
> `["swap"]="swap "-L SWAP" "" discard,pri=100"`
>
> * `discard`: reciclagem automática de sonhos descartáveis.
> * `pri=100`: alta prioridade — pronto para agir quando a RAM falhar.

```
# ----------------------------------------
# 🔧 CONFIGURAÇÕES GLOBAIS
# ----------------------------------------
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



