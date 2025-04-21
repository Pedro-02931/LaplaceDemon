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
    dl ">> Gerando fstab em $FSTAB_PATH..."

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

    dl "✅ fstab gerado com sucesso!"
}

# Execução
gerar_fstab
