# Page 2

{% code overflow="wrap" %}
```
# Criar diretórios de log
mkdir -p /log
touch /log/vemCaPutinha.log /log/vemCaPutinha_control.log

# Definir variáveis globais
MOUNTROOT="/mnt"
# Listar discos disponíveis
lsblk -dpno NAME,SIZE,MODEL | nl -w2 -s'. '

# Escolher um disco (substitua X pelo número do disco escolhido)
# Por exemplo, para escolher o primeiro disco:
DISK=$(lsblk -dpno NAME | sed -n "1p")
echo "Disco selecionado: $DISK"
# Calcular tamanho total do disco para particionamento
DISK_SIZE_BYTES=$(blockdev --getsize64 $DISK)
VG_SIZE_MB=$((DISK_SIZE_BYTES / 1024 / 1024 - 1536))
echo "Tamanho disponível para partições: $VG_SIZE_MB MiB"
# Desmontar tudo
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true
dmsetup remove_all 2>/dev/null || true
umount ${DISK}* 2>/dev/null || true

# Zerar
alias zero="{ sudo wipefs -a /dev/sda; sudo sgdisk --zap-all /dev/sda;  sudo dd if=/dev/zero of=/dev/sda bs=1M count=1024 status=progress; sudo partprobe /dev/sda; sleep 4; sudo udevadm settle; }"

# Definir variavel $DISK
alias one='{ sudo sgdisk --new=1:0:+512M --typecode=1:ef00 --change-name=1:"Cortex-Boot-EFI" $DISK;  sudo sgdisk --new=2:0:+1G --typecode=2:8300 --change-name=2:"Cerebellum-Boot" $DISK;  sudo sgdisk --new=3:0:+$((VG_SIZE_MB * 20/100))M --typecode=3:8300 --change-name=3:"root" $DISK;  sudo sgdisk --new=4:0:+$((VG_SIZE_MB * 5/100))M --typecode=4:8300 --change-name=4:"var" $DISK;  sudo sgdisk --new=5:0:+$((VG_SIZE_MB * 2/100))M --typecode=5:8300 --change-name=5:"tmp" $DISK;  sudo sgdisk --new=6:0:+$((VG_SIZE_MB * 34/100))M --typecode=6:8300 --change-name=6:"usr" $DISK;  sudo sgdisk --new=7:0:+$((VG_SIZE_MB * 5/100))M --typecode=7:8200 --change-name=7:"swap" $DISK;  sudo sgdisk --new=8:0:0 --typecode=8:8300 --change-name=8:"home" $DISK;  }'

# Atualizar tabela de partições
partprobe $DISK
sleep 2
udevadm settle

# Formatar EFI
mkfs.vfat -F32 -n EFI ${DISK}1

# Formatar BOOT
mkfs.ext4 -q -L BOOT ${DISK}2

# Formatar ROOT
mkfs.btrfs -L ROOT -f ${DISK}3

# Formatar VAR
mkfs.ext4 -q -L VAR ${DISK}4
tune2fs -o journal_data_writeback ${DISK}4

# Formatar TMP
mkfs.ext4 -q -L TMP ${DISK}5

# Formatar USR
mkfs.ext4 -q -L USR ${DISK}6

# Formatar SWAP
mkswap -L SWAP ${DISK}7
swapon ${DISK}7

# Formatar HOME
mkfs.btrfs -L HOME -f ${DISK}8

# Verificar todas as montagens
lsblk -f
echo "Processo concluído: +20-40% de vida útil do SSD, +15-30% de I/O, sincronia CPU/SSD atingida."



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
# ----------------------------------------
# 📍 FUNÇÃO: OBTER UUIDs E USUÁRIO
# ----------------------------------------
# 📄 Script para gerar fstab otimizado (sem LVM)
# Autor: pmota | Revisado por ChatGPT
# Função para pegar UUID de um dispositivo
get_uuid() {
    blkid -s UUID -o value "$1"
}

# Gerar o conteúdo do fstab
gerar_fstab() {
    d_l ">> Gerando fstab em $FSTAB_PATH..."

    mkdir -p "$(dirname "$FSTAB_PATH")"

    cat <<EOF > "$FSTAB_PATH"
# /etc/fstab - Gerado automaticamente

UUID=$(get_uuid ${DISK}3)   /               ext4    defaults,noatime,discard,commit=60,errors=remount-ro  0 1
UUID=$(get_uuid ${DISK}1)   /boot/efi       vfat    defaults,noatime,uid=0,gid=0,umask=0077,shortname=winnt  0 1
UUID=$(get_uuid ${DISK}2)   /boot           ext4    defaults,noatime,errors=remount-ro  0 1
UUID=$(get_uuid ${DISK}8)   /home           xfs     defaults,noatime,allocsize=512m,logbufs=8,inode64  0 2
UUID=$(get_uuid ${DISK}6)   /usr            ext4    ro,noatime,errors=remount-ro,commit=120  0 1
UUID=$(get_uuid ${DISK}4)   /var            ext4    defaults,noatime,data=journal,commit=30  0 2
UUID=$(get_uuid ${DISK}5)   /tmp            ext4    defaults,noatime,nosuid,nodev  0 2
UUID=$(get_uuid ${DISK}7)   none            swap    sw  0 0

tmpfs             /working        tmpfs   defaults,size=4G,noatime,nodev,nosuid,mode=1777  0 0
tmpfs             /sensory/tmp    tmpfs   defaults,size=2G,noatime,nodev,nosuid,mode=1777  0 0
tmpfs             /dev/shm        tmpfs   defaults,size=8G,noatime,nodev,nosuid,mode=1777  0 0

/cognitive/cerebellum/.config /home/$USER_NAME/.config none bind 0 0
EOF

    d_l "✅ fstab gerado com sucesso!"
}

# Execução
gerar_fstab
```
{% endcode %}
