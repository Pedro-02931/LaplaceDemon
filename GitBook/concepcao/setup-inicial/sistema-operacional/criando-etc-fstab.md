# Criando /etc/fstab

```
#######DEIXE SEMPRE ALINHADO COM O CABEÇALHO#########
set -euo pipefail

# ----------------------------------------
# ARQUIVOS DE LOG E CONTROLE
# ----------------------------------------
LOG_DIR="/log"
LOG_FILE="$LOG_DIR/vemCaPutinha.history.hardeningBase.log"

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
#############FIM DE CABEÇALHO###################
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

d_l "🔧 Setup inicial: Atualizando sistema e instalando ferramentas base com firmware."
    sleep "$PC"
    c_e "Executar setup básico?" || return

    # 🎯 Atualizando o sources.list de forma otimizada
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
        firmware-misc-nonfree intel-microcode firmware-realtek firmware-iwlwifi firmware-linux intel-media-driver vainfo

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
    
        for cmd in disable purge; do
        balooctl "$cmd"
    done
    
    function configurar_mozilla() {
    local id="mozilla"
    ja_executado "$id" && d_l "⏭️ Mozilla já configurado, pulando..." && return

    d_l "🌐 Mozilla Firefox."
    sleep $PC
    confirmar_execucao "Instalar Firefox oficial e configurar repositório Mozilla?" || return

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

    marcar_como_executado "$id"
}

#------------------------------------------------------------------------------------------------------------------------#

# Função para instalar Visual Studio Code
function instalar_vscode() {
    local id="vscode"
    ja_executado "$id" && d_l "⏭️ VS Code já instalado, pulando..." && return

    d_l "💻 Instalando Visual Studio Code."
    sleep $PC
    confirmar_execucao "Instalar Visual Studio Code?" || return

    # Baixar a chave do repositório da Microsoft
    d_l "🔑 Baixando chave do repositório da Microsoft..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg

    # Adicionar o repositório do VS Code à lista de fontes do APT
    d_l "📦 Adicionando repositório do VS Code..."
    sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null <<EOF
deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main
EOF

    # Atualizar a lista de pacotes
    d_l "🔄 Atualizando lista de pacotes..."
    sudo apt update

    # Tentar instalar o VS Code com redundância (loop for)
    local tentativas=3
    for ((i=1; i<=tentativas; i++)); do
        d_l "🚀 Tentativa $i de instalação do VS Code..."
        sudo apt install -y code
        if [ $? -eq 0 ]; then
            d_l "✅ Visual Studio Code instalado com sucesso!"
            marcar_como_executado "$id"
            return 0
        else
            d_l "⚠️ Falha na tentativa $i. Tentando novamente..."
            sleep 2
        fi
    done

    d_l "❌ Não foi possível instalar o VS Code após $tentativas tentativas."
}
```
