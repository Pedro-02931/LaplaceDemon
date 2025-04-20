#!/bin/bash
# -------------------------
# 💽 PARTIÇÃO E FORMATAÇÃO COMPLETA
# -------------------------
set -euo pipefail

preparar_disco() {
    target_disk="/dev/sda"

    echo ">> Limpando disco $target_disk..."
    umount -R /mnt || true
    swapoff -a || true
    dmsetup remove_all || true
    umount "${target_disk}"* || true

    wipefs -a "$target_disk"
    sgdisk --zap-all "$target_disk"
    dd if=/dev/zero of="$target_disk" bs=1M count=10 status=progress
    partprobe "$target_disk"
    sleep 2
    udevadm settle

    # -------------------------
    # CRIAR PARTIÇÕES
    # -------------------------
    echo ">> Criando partições fixas (EFI + BOOT + LVM)..."

    sgdisk --new=1:0:+512M --typecode=1:ef00 --change-name=1:"Cortex-Boot-EFI" "$target_disk"
    sgdisk --new=2:0:+1G   --typecode=2:8300 --change-name=2:"Cerebellum-Boot" "$target_disk"
    sgdisk --new=3:0:0     --typecode=3:8e00 --change-name=3:"Brainstem-LVM" "$target_disk"

    partprobe "$target_disk"
    sleep 2
    udevadm settle

    # -------------------------
    # CONFIGURAR LVM
    # -------------------------
    echo ">> Configurando LVM..."
    vgremove -f vg0 || true
    pvcreate -ff -y "${target_disk}3"
    vgcreate vg0 "${target_disk}3"

    lvcreate -n root -l 20%VG vg0
    lvcreate -n var  -l 5%VG  vg0
    lvcreate -n tmp  -l 2%VG  vg0
    lvcreate -n usr  -l 25%VG vg0
    lvcreate -n home -l 100%FREE vg0

    # -------------------------
    # FORMATAR
    # -------------------------
    echo ">> Formatando sistemas de arquivos..."
    mkfs.vfat -F32 -n EFI "${target_disk}1"
    mkfs.ext4 -q -L BOOT "${target_disk}2"

    mkfs.ext4 -q -L ROOT /dev/vg0/root
    mkfs.ext4 -q -L VAR  /dev/vg0/var
    mkfs.ext4 -q -L TMP  /dev/vg0/tmp
    mkfs.ext4 -q -L USR  /dev/vg0/usr
    mkfs.ext4 -q -L HOME /dev/vg0/home

    for lv in root var tmp usr home; do
        tune2fs -o journal_data_writeback "/dev/vg0/$lv"
    done

    # -------------------------
    # GRUB (pré-config)
    # -------------------------
    echo ">> Configurando GRUB padrão..."
    mkdir -p /mnt/etc/default
    cat <<EOF > /mnt/etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash nowatchdog mitigations=off elevator=none scsi_mod.use_blk_mq=1"
EOF

    echo "✅ Disco preparado com sucesso!"
}

preparar_disco
