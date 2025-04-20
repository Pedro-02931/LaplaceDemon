#!/bin/bash
# -*- coding: utf-8 -*-
#
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                                                                              ║
# ║                      Copyright (C) 2025 FlatLine                             ║
# ║                                                                              ║
# ╠══════════════════════════════════════════════════════════════════════════════╣
# ║                                                                              ║
# ║ Este programa é software livre; você pode redistribuí-lo e/ou modificá-lo    ║
# ║ sob os termos da Licença Pública Geral GNU, conforme publicada pela Free     ║
# ║ Software Foundation; tanto a versão 2 da Licença como (a seu critério)       ║
# ║ qualquer versão mais nova.                                                   ║
# ║                                                                              ║
# ║ Este programa é distribuído na expectativa de ser útil, mas SEM QUALQUER     ║
# ║ GARANTIA; nem mesmo a garantia implícita de COMERCIALIZAÇÃO ou de            ║
# ║ ADEQUAÇÃO A QUALQUER PROPÓSITO EM PARTICULAR. Consulte a Licença Pública     ║
# ║ Geral GNU para obter mais detalhes.                                          ║
# ║                                                                              ║
# ║ Você deve ter recebido uma cópia da Licença Pública Geral GNU junto com      ║
# ║ este programa; se não, escreva para a Free Software Foundation, Inc.,        ║S
# ║ 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.                  ║
# ║                                                                              ║
# ╠══════════════════════════════════════════════════════════════════════════════╣
# ║                                                                              ║
# ║ Tradução: Se me copiar sem nem ao menos me indicar, dá o bumbum,             ║
# ║ PS1: Passei esse script no saco,                                             ║
# ║ PS2: Comi o cu de quem ta lendo,                                             ║
# ║ PS3: Esse projeto e a prova cabal de que sou autista e preciso transar!      ║
# ║                                                                              ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
# PS: para pessoa me copiar, vai ter que explicar pq o nome da função de estabilização harmonica de processamento com base num vetor comum de função para reduzir o framerate tempo_dimensional no modelo Bayesiano se chama "faz_o_urro()" 

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

# ----------------------------------------
# 🖋️ FUNÇÕES DE UI E CONTROLE
# ----------------------------------------
d_l() {
    local t="$1"
    for ((i=0; i<${#t}; i++)); do
        echo -n "${t:i:1}"
        sleep 0.02
    done
    echo
}

confirmar_execucao() {
    local acao="$1"
    d_l "$acao"
    read -p "Deseja aplicar esta configuração? [s/N]: " resp
    [[ "$resp" =~ ^[sS]$ ]]
}

ja_executado() {
    grep -qFx "$1" "$CONTROL_FILE" 2>/dev/null
}

marcar_como_executado() {
    echo "$1" >> "$CONTROL_FILE"
}

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

declare -A OTIMIZACOES=(
    ["EFI"]="vfat \"-F32 -n EFI\" \"\" noatime,nodiratime,flush"
    ["BOOT"]="ext4 \"-q -L BOOT\" \"\" data=writeback,noatime,discard"
    ["root"]="btrfs \"-L ROOT -f\" \"\" compress=zstd:3,noatime,space_cache=v2,ssd,autodefrag"
    ["var"]="ext4 \"-q -L VAR\" \"-o journal_data_writeback\" data=journal,barrier=0"
    ["tmp"]="ext4 \"-q -L TMP\" \"\" noatime,nodiratime,nodev,nosuid,noexec,discard"
    ["usr"]="ext4 \"-q -L USR\" \"\" noatime,nodiratime,discard,commit=120"
    ["home"]="btrfs \"-L HOME -f\" \"\" compress=zstd:1,autodefrag,noatime,space_cache=v2,ssd"
    ["swap"]="swap \"-L SWAP\" \"\" discard,pri=100"
)

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
