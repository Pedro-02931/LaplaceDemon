#!/bin/bash
set -euo pipefail

# ----------------------------------------
# 📝 ARQUIVOS DE LOG E CONTROLE
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
# 📍 FUNÇÃO: OBTER UUIDs E USUÁRIO
# ----------------------------------------
get_uuids_and_user() {
    d_l "Coletando UUIDs e usuário..."
    UUID_SYSTEM=$(blkid -s UUID -o value "$(findmnt -n -o SOURCE /)")
    UUID_BOOT=$(blkid -s UUID -o value "$(findmnt -n -o SOURCE /boot/efi)")
    if mountpoint -q /home; then
        UUID_HOME=$(blkid -s UUID -o value "$(findmnt -n -o SOURCE /home)")
    else
        UUID_HOME=""
    fi
    USERNAME="${SUDO_USER:-$(whoami)}"
    d_l "Usuário: $USERNAME"
}

# ----------------------------------------
# 📝 FUNÇÃO: CONFIGURAR /etc/fstab
# ----------------------------------------
configurar_fstab() {
    local tag="configurar_fstab"
    if ja_executado "$tag"; then
        d_l ">>> configurar_fstab já executado, pulando."
        return
    fi

    d_l "Gerando /etc/fstab com otimizações..."
    cat <<EOF > /etc/fstab
UUID=$UUID_SYSTEM  /               btrfs   defaults,noatime,compress=zstd:3,autodefrag,space_cache=v2 0 1
UUID=$UUID_BOOT    /boot/efi       vfat    umask=0077 0 1
EOF

    if [[ -n "$UUID_HOME" ]]; then
        cat <<EOF >> /etc/fstab
UUID=$UUID_HOME    /home           xfs     defaults,noatime,largeio,inode64 0 2
EOF
    fi

    cat <<EOF >> /etc/fstab

tmpfs             /working        tmpfs   defaults,size=4G,noatime,nodev,nosuid,mode=1777 0 0
tmpfs             /sensory/tmp    tmpfs   defaults,size=2G,noatime,nodev,nosuid,mode=1777 0 0
tmpfs             /dev/shm        tmpfs   defaults,size=8G,noatime,nodev,nosuid,mode=1777 0 0

/cognitive/cerebellum/.config /home/$USERNAME/.config none bind 0 0
EOF

    marcar_como_executado "$tag"
    d_l "/etc/fstab configurado com sucesso."
}

# ----------------------------------------
# 🧠 FUNÇÃO PRINCIPAL
# ----------------------------------------
main_postinstall() {
    if ! confirmar_execucao "Isto vai sobrescrever /etc/fstab atual"; then
        d_l "Operação cancelada pelo usuário."
        exit 0
    fi
    get_uuids_and_user
    configurar_fstab
    d_l "Post‑install concluído: fstab pronto para montagem otimizada."
}

main_postinstall
