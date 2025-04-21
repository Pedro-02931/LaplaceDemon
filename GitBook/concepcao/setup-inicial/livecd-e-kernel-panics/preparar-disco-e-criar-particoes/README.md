# Preparar Disco E Criar Partições

Primeiro essa função verifica se já foi executada para evitar refazer a limpeza e particionamento, garantindo a segurança; em seguida, executa uma série de comandos de "desmonte":

1. `umount -R` desmonta recursivamente qualquer coisa montada no diretório temporário.
2. `swapoff -a` desativa todas as áreas de swap.
3. `dmsetup remove_all` remove mapeamentos do Device Mapper (como LVMs antigos ou partições criptografadas).
4. `umount "${DISK}"*` tenta desmontar quaisquer partições do disco alvo que ainda possam estar montadas.

A limpeza profunda segue:

1. `wipefs -a` que apaga assinaturas de sistemas de arquivos e partições diretamente nos setores iniciais e finais.
2. `sgdisk --zap-all` que destrói a tabela de partição GPT (ou MBR) existente
3. `dd if=/dev/zero ...` que sobrescreve os primeiros 100 megabytes do disco com zeros, garantindo a remoção de bootloaders antigos e metadados persistentes.
4. `partprobe` e `udevadm settle` pedem ao kernel e ao sistema para relerem a tabela de partição (agora vazia) e atualizarem o estado dos dispositivos.&#x20;

Finalmente a parte mecanica e repetitiva do `sgdisk --new...`, que cria as novas partições:&#x20;

* uma EFI de 512MB (código `ef00`),&#x20;
* uma /boot de 1GB (código `8300` - Linux filesystem),
* E outras caralhadas pro SO modulável através do `for...loop`

{% code overflow="wrap" %}
```bash
preparar_disco() {
    local tag="preparar_disco"
    if ja_executado "$tag"; then
        d_l ">>> preparar_disco já executado, pulando."
        return
    fi
    d_l "Limpando disco $DISK..."
    umount -R "$MOUNTROOT"
    swapoff -a
    dmsetup remove_all
    umount "${DISK}"*

    wipefs -a "$DISK"
    sgdisk --zap-all "$DISK"
    dd if=/dev/zero of="$DISK" bs=1M count=10 status=progress
    partprobe "$DISK"; sleep 2; udevadm settle

    d_l "Criando partições diretas (sem LVM)..."
    sgdisk --new=1:0:+512M --typecode=1:ef00 --change-name=1:"Cortex-Boot-EFI" "$DISK"
    sgdisk --new=2:0:+1G --typecode=2:8300 --change-name=2:"Cerebellum-Boot" "$DISK"
    
    local idx=3
    local p=("root" "var" "tmp" "usr" "swap" "home")
    for part in "${p[@]}"; do
        if [[ "$part" == "home" ]]; then
            sgdisk --new=$idx:0:0 --typecode=$idx:8300 --change-name=$idx:"$part" "$DISK"
        elif [[ "$part" == "swap" ]]; then
            sgdisk --new=$idx:0:+$((VG_SIZE_MB * PERCENTUAIS[$part]/100))M --typecode=$idx:8200 --change-name=$idx:"$part" "$DISK"
        else
            sgdisk --new=$idx:0:+$((VG_SIZE_MB * PERCENTUAIS[$part]/100))M --typecode=$idx:8300 --change-name=$idx:"$part" "$DISK"
        fi
        ((idx++))
    done
    
    partprobe "$DISK"; sleep 2; udevadm settle
    marcar_como_executado "$tag"
    d_l "Disco preparado com sucesso."
}
```
{% endcode %}
