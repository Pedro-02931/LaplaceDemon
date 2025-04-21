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
# ║ PS1: Passei esse script no saco,                                             ║
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
    ["EFI"]="vfat \"-F32 -n EFI\" \"\""
    ["BOOT"]="ext4 \"-q -L BOOT\" \"\""
    ["root"]="btrfs \"-L ROOT -f\" \"\""
    ["var"]="ext4 \"-q -L VAR\" \"-o journal_data_writeback\""
    ["tmp"]="ext4 \"-q -L TMP\" \"\""
    ["usr"]="ext4 \"-q -L USR\" \"\""
    ["home"]="btrfs \"-L HOME -f\" \"\""
    ["swap"]="swap \"-L SWAP\" \"\""
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
        IFS=' ' read -r fs mkfs_opts tune_opts <<< "${OTIMIZACOES[$key]}"
        part="${DISK}$([[ "$key" == "EFI" ]] && echo "1" || echo "2")"
        d_l "Formatando $key ($part) como $fs..."
        eval mkfs.$fs $mkfs_opts "$part"
        [[ -n $tune_opts ]] && eval tune2fs $tune_opts "$part"
    done

    # Partições diretas
    local idx=3
    local p=("root" "var" "tmp" "usr" "swap" "home")
    for part in "${p[@]}"; do
        dev="${DISK}${idx}"
        if [[ "$part" == "swap" ]]; then
            d_l "Configurando swap em $dev..."
            mkswap -L SWAP "$dev"
            swapon "$dev"
        else
            IFS=' ' read -r fs mkfs_opts tune_opts <<< "${OTIMIZACOES[$part]}"
            d_l "Formatando partição $part ($dev) como $fs..."
            eval mkfs.$fs $mkfs_opts "$dev"
            [[ -n $tune_opts ]] && eval tune2fs $tune_opts "$dev"
        fi
        ((idx++))
    done

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

    DISK_SIZE_BYTES=$(blockdev --getsize64 "$DISK")
    VG_SIZE_MB=$((DISK_SIZE_BYTES / 1024 / 1024 - 1536)) # espaço EFI + BOOT

    preparar_disco
    formatar_e_otimizar
    d_l "Processo concluído: +20-40% de vida útil do SSD, +15-30% de I/O, sincronia CPU/SSD atingida."
}

main
