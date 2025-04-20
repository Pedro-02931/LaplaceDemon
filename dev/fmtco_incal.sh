#!/bin/bash
# -------------------------
# 💽 PARTIÇÃO E FORMATAÇÃO COMPLETA
# -------------------------
set -euo pipefail
apt install grub-efi-amd64 shim-helpers-amd64-signed shim-unsigned grub-common os-prober

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

mountar_particoes() {
mount /dev/vg0/root /mnt
mkdir -p /mnt/{boot,home,var,tmp,usr}
mount /dev/vg0/home /mnt/home
mount /dev/vg0/var /mnt/var
mount /dev/vg0/tmp /mnt/tmp
mount /dev/vg0/usr /mnt/usr

mount /dev/sda2 /mnt/boot
mkdir -p /mnt/boot/efi
mount /dev/sda1 /mnt/boot/efi
}

montar_particoes

copiar_arquivos() {
rsync -aAXv / /mnt \
  --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"}

}
copiar_arquivos




gerar_fstab() {
    #!/bin/bash
# Gerador automático de /etc/fstab otimizado para sistema com LVM, SSD e RAMDISK
# Autor: ChatGPT | User: pmota

set -euo pipefail

# Nome do usuário
USERNAME="pmota"

# Detecta os UUIDs das partições montadas
get_uuid() {
    blkid -s UUID -o value "$1"
}

ROOT_UUID=$(get_uuid /dev/mapper/vg0-root)
BOOT_UUID=$(get_uuid /dev/sda2)
EFI_UUID=$(get_uuid /dev/sda1)
HOME_UUID=$(get_uuid /dev/mapper/vg0-home)
VAR_UUID=$(get_uuid /dev/mapper/vg0-var)
TMP_UUID=$(get_uuid /dev/mapper/vg0-tmp)
USR_UUID=$(get_uuid /dev/mapper/vg0-usr)

# Criação do fstab
cat <<EOF > /mnt/etc/fstab
# /etc/fstab - Arquivo gerado automaticamente

UUID=$ROOT_UUID   /               ext4    defaults,noatime,discard,commit=60,errors=remount-ro  0 1
UUID=$EFI_UUID    /boot/efi       vfat    defaults,noatime,uid=0,gid=0,umask=0077,shortname=winnt  0 1
UUID=$BOOT_UUID   /boot           ext4    defaults,noatime,errors=remount-ro  0 1
UUID=$HOME_UUID   /home           xfs     defaults,noatime,allocsize=512m,logbufs=8,inode64  0 2
UUID=$USR_UUID    /usr            ext4    ro,noatime,errors=remount-ro,commit=120  0 1
UUID=$VAR_UUID    /var            ext4    defaults,noatime,data=journal,commit=30  0 2
UUID=$TMP_UUID    /tmp            ext4    defaults,noatime,nosuid,nodev  0 2

tmpfs             /working        tmpfs   defaults,size=4G,noatime,nodev,nosuid,mode=1777  0 0
tmpfs             /sensory/tmp    tmpfs   defaults,size=2G,noatime,nodev,nosuid,mode=1777  0 0
tmpfs             /dev/shm        tmpfs   defaults,size=8G,noatime,nodev,nosuid,mode=1777  0 0

/cognitive/cerebellum/.config /home/$USERNAME/.config none bind 0 0
EOF

echo "✅ /etc/fstab otimizado gerado em /mnt/etc/fstab"
}


configurar_sysctl() {
    cat <<EOF > /etc/sysctl.d/99-neurofocus.conf
vm.swappiness=10
vm.vfs_cache_pressure=50
fs.inotify.max_user_watches=524288
EOF

    cat <<EOF > /etc/sysctl.d/99-neuro-memory.conf
vm.swappiness=30
vm.dirty_ratio=15
vm.dirty_background_ratio=3
vm.vfs_cache_pressure=50
vm.watermark_scale_factor=200
EOF

    sysctl --system
}


setup() {
sudo tee /etc/apt/sources.list > /dev/null <<'EOF'
# Repositórios principais
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm main non-free-firmware

# Atualizações estáveis
deb http://deb.debian.org/debian bookworm-updates main non-free-firmware
deb-src http://deb.debian.org/debian bookworm-updates main non-free-firmware

# Segurança
deb http://security.debian.org/debian-security bookworm-security main non-free-firmware
deb-src http://security.debian.org/debian-security bookworm-security main non-free-firmware

# Backports (versões mais recentes de pacotes estáveis)
deb http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm-backports main non-free-firmware
EOF
    sudo apt update && sudo apt full-upgrade -y

    local p=(
        # 🛠️ Ferramentas de desenvolvimento e utilitários
        build-essential default-jdk libssl-dev exuberant-ctags ncurses-term ack silversearcher-ag
        fontconfig imagemagick libmagickwand-dev software-properties-common vim-gtk3 curl
        neovim cmdtest npm git

        # 🔐 Segurança e rede
        ufw fail2ban

        # 🐍 Python
        python3 python3-pip python3-venv

        # 🔥 Otimizações de desempenho
        cpufrequtils tlp numactl preload

        # 📦 Firmware e drivers essenciais
        firmware-misc-nonfree intel-microcode firmware-realtek firmware-iwlwifi firmware-linux

        # 🕹️ Vulkan, Mesa e drivers gráficos
        mesa-utils mesa-vulkan-drivers vulkan-tools libvulkan1

        # 🎮 Modo de desempenho para jogos/apps
        gamemode
    )

    sudo apt install -y "${p[@]}"
        ### 🔧 Auto-configurações após instalação
    # Python3 como padrão
    command -v python >/dev/null || sudo ln -s /usr/bin/python3 /usr/local/bin/python
    python --version && pip3 install --upgrade pip

    # TLP
    sudo systemctl enable tlp
    sudo systemctl start tlp

    # preload
    sudo systemctl enable preload
    sudo systemctl start preload

    # ZSH como padrão + oh-my-zsh
    if command -v zsh >/dev/null; then
        chsh -s "$(which zsh)" "$USER"
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi

    # UFW + Fail2ban
    sudo systemctl enable ufw && sudo ufw enable
    sudo systemctl enable fail2ban && sudo systemctl start fail2ban
}

configurar_io_scheduler() {
    cat <<EOF > /etc/udev/rules.d/60-iosched.rules
ACTION=="add|change", KERNEL=="sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
EOF
    udevadm control --reload-rules && udevadm trigger
    apt install -y tuned
    tuned-adm profile latency-performance
    systemctl enable --now tuned.service
}
instalar_mozila_code(){
sudo install -d -m 0755 /etc/apt/keyrings
    sudo apt-get install -y wget
    wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc >/dev/null

    sudo tee /etc/apt/sources.list.d/mozilla.list >/dev/null <<EOF
deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main
EOF

    sudo tee /etc/apt/preferences.d/mozilla >/dev/null <<EOF
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

    sudo apt-get update
    sudo apt-get install -y firefox
    sudo apt purge -y firefox-esr
    sudo apt autoremove -y

    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg

    # Adicionar o repositório do VS Code à lista de fontes do APT    sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null <<EOF
deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main
EOF
sudo apt install -y code
}
chroot_config() {
mount -t proc /proc /mnt/proc
mount --rbind /sys /mnt/sys
mount --rbind /dev /mnt/dev
sudo chroot /mnt /bin/bash
gerar_fstab
echo "FlatLine" > /etc/hostname
configurar_sysctl
setup
configurar_io_scheduler

    for cmd in disable purge; do
        balooctl "$cmd"
    done
    balooctl status
    curl -s 'https://liquorix.net/add-liquorix-repo.sh' | sudo bash
instalar_mozila_code 

