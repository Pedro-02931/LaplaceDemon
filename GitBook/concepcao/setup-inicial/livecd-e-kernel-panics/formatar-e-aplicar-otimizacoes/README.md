---
description: >-
  Protegido pela GPL2 - Linkedin:
  https://www.linkedin.com/in/pedro-mota-95046b356/
---

# Formatar E Aplicar Otimizações

Este é o clímax, onde aplicamos as configurações finas que realmente fazem a diferença no dia a dia, aqui pegamos as estruturas criadas (partições físicas EFI/BOOT e LVs) e damos vida a elas com sistemas de arquivos específicos e opções de montagem otimizadas.

A função primeiro lida com as partições físicas de boot:&#x20;

* Para EFI usa `vfat` (FAT32) com opções `noatime,nodiratime,flush` para reduzir escritas desnecessárias e garantir que dados importantes sejam gravados rapidamente,
*   Para BOOT usa `ext4` com `data=writeback,noatime,discard` combinando velocidade de escrita, redução de metadados e suporte a TRIM para SSDs.&#x20;

    > 1. O `eval mkfs...` cria o sistema de arquivos,&#x20;
    > 2. `eval tune2fs...` aplica ajustes finos (se houver),&#x20;
    > 3. `mkdir` cria o ponto de montagem,
    > 4. `mount -o ...` monta a partição com as opções definidas.

A segunda parte faz o mesmo para os outros Volumes (`root`, `var`, `tmp`, `usr`, `home`), mas aqui as otimizações são ainda mais cruciais e variadas:&#x20;

* `root` e `home` usam `btrfs` com compressão `zstd` (nível 3 para root, mais agressivo, nível 1 para home, mais leve), `noatime` para economizar escritas, `space_cache=v2` e `ssd` para otimizar alocação em SSDs e `autodefrag` para combater a fragmentação;&#x20;
* `var` (logs e dados variáveis) usa `ext4` com `data=journal,barrier=0` focado um pouco mais em segurança dos dados mas ainda rápido;&#x20;
* `tmp` (temporários) usa `ext4` com `noatime,nodiratime,nodev,nosuid,noexec,discard` focando em velocidade e segurança (impedindo execução de binários);&#x20;
* `usr` (programas) usa `ext4` com `noatime,nodiratime,discard,commit=120` adiando escritas de metadados para agrupar operações.&#x20;
* cria-se um `swapfile` (em vez de partição) com `fallocate`, ajustanado permissões (`chmod 600`), formata com `mkswap` e ativa com `swapon`, usando um arquivo que pode ser facilmente redimensionado ou removido depois, oferecendo mais flexibilidade que uma partição swap fixa.

{% code overflow="wrap" %}
```bash
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
        eval mkfs.$fs $mkfs_opts "$part" 2>>"$LOG_FILE"
        [[ -n $tune_opts ]] && eval tune2fs $tune_opts "$part" 2>>"$LOG_FILE"
        mkdir -p "$MOUNTROOT/$([[ "$key" == "EFI" ]] && echo "boot/efi" || echo "boot")" 2>>"$LOG_FILE"
        mount -o "$mount_opts" "$part" "$MOUNTROOT/$([[ "$key" == "EFI" ]] && echo "boot/efi" || echo "boot")" 2>>"$LOG_FILE"
    done
    
    # Partições diretas
    local idx=3
    local p=("root" "var" "tmp" "usr" "swap" "home")
    for part in "${p[@]}"; do
        if [[ "$part" == "swap" ]]; then
            d_l "Configurando swap em ${DISK}${idx}..."
            mkswap -L SWAP "${DISK}${idx}" 2>>"$LOG_FILE"
            swapon "${DISK}${idx}" 2>>"$LOG_FILE"
        else
            IFS=' ' read -r fs mkfs_opts tune_opts mount_opts <<< "${OTIMIZACOES[$part]}"
            dev="${DISK}${idx}"
            d_l "Formatando partição $part ($dev) como $fs..."
            eval mkfs.$fs $mkfs_opts "$dev" 2>>"$LOG_FILE"
            [[ -n $tune_opts ]] && eval tune2fs $tune_opts "$dev" 2>>"$LOG_FILE"
            mkdir -p "$MOUNTROOT/$part" 2>>"$LOG_FILE"
            mount -o "$mount_opts" "$dev" "$MOUNTROOT/$part" 2>>"$LOG_FILE"
        fi
        ((idx++))
    done
    
    marcar_como_executado "$tag"
    d_l "Formatação e otimizações aplicadas."
}
```
{% endcode %}

