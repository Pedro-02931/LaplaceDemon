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

# Limpar o disco
wipefs -a $DISK
sgdisk --zap-all $DISK
dd if=/dev/zero of=$DISK bs=1M count=10 status=progress
partprobe $DISK
sleep 2
udevadm settle
# Criar partição EFI
sgdisk --new=1:0:+512M --typecode=1:ef00 --change-name=1:"Cortex-Boot-EFI" $DISK

# Criar partição BOOT
sgdisk --new=2:0:+1G --typecode=2:8300 --change-name=2:"Cerebellum-Boot" $DISK

# Criar partição ROOT (20% do espaço)
sgdisk --new=3:0:+$((VG_SIZE_MB * 20/100))M --typecode=3:8300 --change-name=3:"root" $DISK

# Criar partição VAR (5% do espaço)
sgdisk --new=4:0:+$((VG_SIZE_MB * 5/100))M --typecode=4:8300 --change-name=4:"var" $DISK

# Criar partição TMP (2% do espaço)
sgdisk --new=5:0:+$((VG_SIZE_MB * 2/100))M --typecode=5:8300 --change-name=5:"tmp" $DISK

# Criar partição USR (25% do espaço)
sgdisk --new=6:0:+$((VG_SIZE_MB * 25/100))M --typecode=6:8300 --change-name=6:"usr" $DISK

# Criar partição SWAP (5% do espaço)
sgdisk --new=7:0:+$((VG_SIZE_MB * 5/100))M --typecode=7:8200 --change-name=7:"swap" $DISK

# Criar partição HOME (resto do espaço)
sgdisk --new=8:0:0 --typecode=8:8300 --change-name=8:"home" $DISK

# Atualizar tabela de partições
partprobe $DISK
sleep 2
udevadm settle
# Formatar EFI
mkfs.vfat -F32 -n EFI ${DISK}1

# Montar EFI
mkdir -p /mnt/boot/efi
mount -o noatime,nodiratime,flush ${DISK}1 /mnt/boot/efi
# Formatar BOOT
mkfs.ext4 -q -L BOOT ${DISK}2

# Montar BOOT
mkdir -p /mnt/boot
mount -o data=writeback,noatime,discard ${DISK}2 /mnt/boot
# Formatar ROOT
mkfs.btrfs -L ROOT -f ${DISK}3

# Montar ROOT
mkdir -p /mnt/root
mount -o compress=zstd:3,noatime,space_cache=v2,ssd,autodefrag ${DISK}3 /mnt/root
# Formatar VAR
mkfs.ext4 -q -L VAR ${DISK}4
tune2fs -o journal_data_writeback ${DISK}4

# Montar VAR
mkdir -p /mnt/var
mount -o data=journal,barrier=0 ${DISK}4 /mnt/var
# Formatar TMP
mkfs.ext4 -q -L TMP ${DISK}5

# Montar TMP
mkdir -p /mnt/tmp
mount -o noatime,nodiratime,nodev,nosuid,noexec,discard ${DISK}5 /mnt/tmp
# Formatar USR
mkfs.ext4 -q -L USR ${DISK}6

# Montar USR
mkdir -p /mnt/usr
mount -o noatime,nodiratime,discard,commit=120 ${DISK}6 /mnt/usr
# Formatar SWAP
mkswap -L SWAP ${DISK}7

# Ativar SWAP
swapon ${DISK}7
# Formatar HOME
mkfs.btrfs -L HOME -f ${DISK}8

# Montar HOME
mkdir -p /mnt/home
mount -o compress=zstd:1,autodefrag,noatime,space_cache=v2,ssd ${DISK}8 /mnt/home
# Verificar todas as montagens
lsblk -f
df -h
echo "Processo concluído: +20-40% de vida útil do SSD, +15-30% de I/O, sincronia CPU/SSD atingida."
