# Criando /etc/fstab

```
#!/bin/bash
########## CABEÇALHO PADRÃO - SEGURANÇA E LOG ##########
set -euo pipefail

# ----------------------------------------
# 🧾 LOG E CONTROLE
# ----------------------------------------
LOG_DIR="/log"
LOG_FILE="$LOG_DIR/vemCaPutinha.history.hardeningBase.log"
CONTROL_FILE="$LOG_DIR/.controle_execucoes"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE" "$CONTROL_FILE"

# Redireciona stdout para /dev/null e stderr para o LOG_FILE
exec 3>&1
exec 1>/dev/null 2>>"$LOG_FILE"

# Ao sair, se houver erros no log, exibe-os
trap 'if [[ -s "$LOG_FILE" ]]; then
          echo -e "\n🛑 Erros detectados (apenas stderr foi salvo):" >&3
          cat "$LOG_FILE" >&3
      fi' EXIT

# ----------------------------------------
# 🚨 TRATAMENTO DE ERROS
# ----------------------------------------
trap 'echo "Erro na linha $LINENO" >&2; exit 1' ERR

# ----------------------------------------
# 🖋️ UI e CONTROLE DE TAREFAS
# ----------------------------------------

# Animação de digitação lenta no terminal
d_l() {
    local t="$1"
    for ((i=0; i<${#t}; i++)); do
        echo -n "${t:i:1}"
        sleep 0.02
    done
    echo
}

# Registra e verifica tarefas para evitar reexecução
ja_executado()   { grep -qFx "$1" "$CONTROL_FILE" 2>/dev/null; }
marcar_como_executado() { echo "$1" >> "$CONTROL_FILE"; }

############# FIM DO CABEÇALHO #################

# ----------------------------------------
# 🔍 Função: gerar_fstab()
# Descrição:
#   - Usa memória de cruzamento (hash table) para mapear pontos de montagem
#   - Itera via for-loop, reduz duplicidade e facilita manutenção
#   - Cria automaticamente o /etc/fstab otimizado
# ----------------------------------------
gerar_fstab() {
    d_l ">> Gerando fstab em $FSTAB_PATH..."
    mkdir -p "$(dirname "$FSTAB_PATH")"
    declare -A cruzamento=(
        ["/"]="ext4 defaults,noatime,discard,commit=60,errors=remount-ro 0 1"
        ["/boot"]="ext4 defaults,noatime,errors=remount-ro 0 1"
        ["/boot/efi"]="vfat defaults,noatime,uid=0,gid=0,umask=0077,shortname=winnt 0 1"
        ["/home"]="xfs defaults,noatime,allocsize=512m,logbufs=8,inode64 0 2"
        ["/usr"]="ext4 ro,noatime,errors=remount-ro,commit=120 0 1"
        ["/var"]="ext4 defaults,noatime,data=journal,commit=30 0 2"
        ["/tmp"]="ext4 defaults,noatime,nosuid,nodev 0 2"
        ["none"]="swap sw 0 0"
    )
    local mnts=("/" "/boot/efi" "/boot" "/home" "/usr" "/var" "/tmp" "none")
    local uuids=("${DISK}3" "${DISK}1" "${DISK}2" "${DISK}8" "${DISK}6" "${DISK}4" "${DISK}5" "${DISK}7")
    echo "# /etc/fstab - Gerado automaticamente" > "$FSTAB_PATH"
    for i in "${!mnts[@]}"; do
        mp="${mnts[$i]}"
        uuid=$(blkid -s UUID -o value "${uuids[$i]}")
        echo "UUID=$uuid   $mp   ${cruzamento[$mp]}" >> "$FSTAB_PATH"
    done
}

# ----------------------------------------
# 🔧 Função: setup_basico()
# Descrição:
#   - Configura todos os repositórios APT (incluindo firmware fechado)
#   - Instala pacotes agrupados por propósito, com comentários inline
#   - Habilita e ajusta serviços principais via systemctl e arquivos de conf
#   - Configura ZSH + alias BANKAI para voltar ao Bash
# ----------------------------------------
setup_basico() {
    d_l "🔧 Setup inicial: repositórios e pacotes"
    # Repositórios APT completos com firmware closed‑source
    sudo tee /etc/apt/sources.list > /dev/null <<'EOF'
# Debian Stable principal (inclui firmware proprietário para hardware moderno)
deb     http://deb.debian.org/debian              bookworm             main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian              bookworm             main contrib non-free-firmware

# Atualizações pós‑lançamento
deb     http://deb.debian.org/debian              bookworm-updates     main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian              bookworm-updates     main contrib non-free-firmware

# Segurança crítica
deb     http://security.debian.org/debian-security bookworm-security    main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security bookworm-security    main contrib non-free-firmware

# Backports (novas versões mantendo base estável)
deb     http://deb.debian.org/debian              bookworm-backports   main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian              bookworm-backports   main contrib non-free-firmware
EOF

    sudo apt update && sudo apt full-upgrade -y

    # Instalação agrupada de pacotes
    local pacotes=(
        # Desenvolvimento (compiladores, ferramentas C/C++, JDK, Python)
        build-essential default-jdk python3 python3-pip python3-venv
        libssl-dev exuberant-ctags ncurses-term ack silversearcher-ag
        # Utilitários GUI e CLI
        fontconfig imagemagick libmagickwand-dev software-properties-common
        vim-gtk3 neovim cmdtest npm curl git
        # Segurança e rede
        ufw fail2ban
        # Performance e energia
        cpufrequtils tlp numactl preload
        # Firmware e drivers essenciais
        firmware-misc-nonfree intel-microcode firmware-realtek firmware-iwlwifi firmware-linux intel-media-driver vainfo
        # Gráficos e Vulkan
        mesa-utils mesa-vulkan-drivers vulkan-tools libvulkan1
        # Gaming
        gamemode
    )
    sudo apt install -y "${pacotes[@]}"

    # Pós-instalação básica
    command -v python >/dev/null || sudo ln -s /usr/bin/python3 /usr/local/bin/python
    python --version && pip3 install --upgrade pip

    # Serviços e configurações iniciais
    sudo systemctl enable --now tlp preload ufw fail2ban

    # Configurações adicionais de TLP e preload ficam nas funções específicas

    # ZSH + alias BANKAI
    if command -v zsh >/dev/null; then
        chsh -s "$(which zsh)" "$USER"
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        echo "alias BANKAI='chsh -s /bin/bash'" >> ~/.zshrc
    fi
}

# ----------------------------------------
# 🛠️ Função: optimize_dev_packages()
# Descrição:
#   - Otimiza GCC, JDK e Python para máxima performance de build
# ----------------------------------------
: <<'EOF'
GCC (build-essential):
  -march=native: usa instruções específicas da CPU local (AVX, etc.)
  -O3: otimizações agressivas de velocidade
  -pipe: usa pipes em vez de arquivos temporários
  -flto: Link Time Optimization para reduzir branch misprediction

Java (JDK):
  Parallel GC: multithreaded GC reduz pausas
  HeapFreeRatio: controla balanço de memória livre

Python:
  --enable-optimizations: compila CPython com otimizações (PGO, LTO)
  -j $(nproc): paraleliza compilação de módulos C usando todos os cores
EOF
optimize_dev_packages() {
    d_l "🔧 Otimizando pacotes de desenvolvimento"
    # GCC
    export CFLAGS="-march=native -O3 -pipe -flto"
    export CXXFLAGS="$CFLAGS"
    echo 'export CFLAGS="-march=native -O3 -pipe -flto"' >> ~/.bashrc
    echo 'export CXXFLAGS="$CFLAGS"'         >> ~/.bashrc

    # Java
    sudo tee -a /etc/environment > /dev/null <<'EOF'
_JAVA_OPTIONS="-XX:+UseParallelGC -XX:MaxHeapFreeRatio=20 -XX:MinHeapFreeRatio=10"
EOF

    # Python
    pip3 config set global.compile-args "-j $(nproc) --enable-optimizations"
    echo "export PYTHONPYCACHEPREFIX='/tmp/__pycache__'" >> ~/.bashrc
}

# ----------------------------------------
# 🎨 Função: optimize_imagemagick()
# Descrição:
#   - Remove restrições de segurança em policy.xml
#   - Habilita uso de SIMD e aceleração via OpenCL/GPU
# ----------------------------------------
: <<'EOF'
ImageMagick:
  Remove policy que bloqueia coders para processar imagens grandes
  Configura limites de resource para:
    memory: 8GiB
    width/height: 32KP (processamento de imagens até ~32.000px)
  Permite uso interno de SIMD/MMX/SSE/AVX e OpenCL para GPU
EOF
optimize_imagemagick() {
    d_l "🔧 Otimizando ImageMagick (SIMD/GPU)"
    sudo sed -i '/<policy domain="coder" rights="none"/d' /etc/ImageMagick-6/policy.xml
    sudo tee /etc/ImageMagick-6/policy.xml > /dev/null <<'EOF'
<policymap>
  <policy domain="resource" name="memory" value="8GiB"/>
  <policy domain="resource" name="width"  value="32KP"/>
  <policy domain="resource" name="height" value="32KP"/>
</policymap>
EOF
}

# ----------------------------------------
# 🔥 Função: optimize_ufw()
# Descrição:
#   - Limita SSH contra brute‑force
#   - Abre portas DNS/NTP de saída
#   - Ajusta conntrack TCP para liberar memória mais rápido
# ----------------------------------------
: <<'EOF'
UFW:
  limit 22/tcp: token bucket para SYN, evita SYN floods
  allow out 80,443,123/udp: libera DNS (53), HTTPS (443) e NTP (123)
  nf_conntrack_tcp_timeout_established: reduz timeout de conexões estabelecidas
EOF
optimize_ufw() {
    d_l "🔧 Otimizando UFW"
    sudo ufw limit 22/tcp
    sudo ufw allow out 80,443,123/udp
    sudo sysctl -w net.netfilter.nf_conntrack_tcp_timeout_established=1200
}

# ----------------------------------------
# 🔋 Função: optimize_tlp()
# Descrição:
#   - Ajusta TLP para equilíbrio energia/performance
# ----------------------------------------
: <<'EOF'
TLP:
  CPU_BOOST_ON_AC=1: turbo boost via AC (alto desempenho)
  CPU_BOOST_ON_BAT=0: desativa boost em bateria (economia)
  SCHED_POWERSAVE_ON_BAT=1: usa governor powersave em bateria
  PCIE_ASPM_ON_BAT=powersupersave: baixa energia PCIe em bateria
  DISK_APM_LEVEL_ON_BAT: define APM em 127 (baixo consumo)
EOF
optimize_tlp() {
    d_l "🔧 Otimizando TLP"
    sudo tee -a /etc/tlp.conf > /dev/null <<'EOF'
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0
SCHED_POWERSAVE_ON_BAT=1
PCIE_ASPM_ON_BAT=powersupersave
DISK_DEVICES="sda sdb"
DISK_APM_LEVEL_ON_BAT="127 127"
EOF
    sudo systemctl restart tlp
}

# ----------------------------------------
# 🚀 Função: optimize_preload()
# Descrição:
#   - Ajusta cache pressure
#   - Configura modelo ML (random forest + hybrid) para prefetch
# ----------------------------------------
: <<'EOF'
Preload:
  vm.vfs_cache_pressure=50: mantém inodes/dentry em cache
  model-ext=random_forest: usa modelo de floresta aleatória
  prediction-method hybrid: mescla regressão logística e neural nets
  preload-level=aggressive: prefetch agressivo baseado em histórico
EOF
optimize_preload() {
    d_l "🔧 Otimizando Preload"
    sudo sysctl -w vm.vfs_cache_pressure=50
    sudo tee /etc/preload.conf > /dev/null <<'EOF'
model-ext = (random_forest);
prediction-method = (hybrid[60%_LR,40%_NN]);
preload-level = aggressive;
EOF
    sudo systemctl restart preload
}

# ----------------------------------------
# ⚙️ Função: optimize_intel_firmware()
# Descrição:
#   - Ativa GuC (offload scheduling) e FBC (compression) no i915
# ----------------------------------------
: <<'EOF'
Intel i915:
  enable_guc=3: offload GPU scheduling para microcódigo
  enable_fbc=1: comprime frame buffer para economizar banda
  enable_psr=0: desativa Panel Self Refresh se causar incompatibilidade
EOF
optimize_intel_firmware() {
    d_l "🔧 Otimizando firmware Intel i915"
    sudo tee /etc/modprobe.d/i915.conf > /dev/null <<'EOF'
options i915 enable_guc=3 enable_fbc=1 enable_psr=0
EOF
}

# ----------------------------------------
# 🎮 Função: optimize_vulkan_mesa()
# Descrição:
#   - Força driver Iris e ICD Intel via profile
# ----------------------------------------
: <<'EOF'
Vulkan/Mesa:
  VK_ICD_FILENAMES: aponta para o ICD Intel
  MESA_LOADER_DRIVER_OVERRIDE=iris: força uso do driver Iris otimizado
EOF
optimize_vulkan_mesa() {
    d_l "🔧 Otimizando Vulkan/Mesa"
    sudo tee /etc/profile.d/vulkan.sh > /dev/null <<'EOF'
export VK_ICD_FILENAMES="/usr/share/vulkan/icd.d/intel_icd.x86_64.json"
export MESA_LOADER_DRIVER_OVERRIDE=iris
EOF
    source /etc/profile.d/vulkan.sh
}

# ----------------------------------------
# 🕹️ Função: optimize_gamemode()
# Descrição:
#   - Configura GameMode para otimização de processos e GPU
# ----------------------------------------
: <<'EOF'
GameMode:
  softrealtime=on: SCHED_RR para processo de jogo
  ioprio=high: I/O classe realtime
  apply_gpu_optimisations: perfis de GPU para máximo desempenho
EOF
optimize_gamemode() {
    d_l "🔧 Otimizando GameMode"
    sudo tee /usr/share/gamemode/gamemode.ini > /dev/null <<'EOF'
[general]
softrealtime=on
ioprio=high
reaper=1

[gpu]
apply_gpu_optimisations=accept_performance
gpu_device=0
EOF
    sudo systemctl enable --now gamemoded
}

# ----------------------------------------
# 🔧 Função: optimize_kernel_tweaks()
# Descrição:
#   - Ajusta parâmetros de rede e memória no kernel
# ----------------------------------------
: <<'EOF'
Kernel Tweaks:
  net.core.{r,w}mem_max: aumenta buffers de rede para 16MiB
  tcp_fastopen=3: habilita Fast Open cliente+servidor
  tcp_congestion_control=bbr: usa algoritmo BBR para menor RTT
  vm.swappiness=10: troca menos para swap, prioriza cache em RAM
EOF
optimize_kernel_tweaks() {
    d_l "🔧 Aplicando kernel tweaks"
    sudo tee /etc/sysctl.d/99-optimize.conf > /dev/null <<'EOF'
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_congestion_control=bbr
vm.swappiness=10
EOF
    sudo sysctl --system
}

# ----------------------------------------
# 🔄 Função: optimize_numa()
# Descrição:
#   - Cria serviço systemd para balanceamento/interleaving NUMA
# ----------------------------------------
: <<'EOF'
NUMA/CPU Affinity:
  --interleave=all: distribui páginas entre nós numa
  --cpunodebind=0: fixa threads no nó 0 para baixa latência
EOF
optimize_numa() {
    d_l "🔧 Configurando NUMA balancing"
    sudo tee /etc/systemd/system/numa.service > /dev/null <<'EOF'
[Unit]
Description=NUMA Balancing

[Service]
Type=oneshot
ExecStart=/usr/bin/numactl --interleave=all --cpunodebind=0

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable --now numa.service
}

# ----------------------------------------
# 🌐 Função: faz_o_urro()
# Descrição:
#   - Instala Firefox oficial e VS Code em sequência
#   - Configura repositórios e chaves de ambos
# ----------------------------------------
: <<'EOF'
faz_o_urro():
  - Mozilla Firefox
  - Visual Studio Code
  Sem loops de tentativa; é direto e conciso.
EOF
faz_o_urro() {
    d_l "🌐💻 Instalando Firefox e VS Code"
    # Firefox
    sudo apt-get install -y wget gnupg
    sudo install -d -m0755 /etc/apt/keyrings
    wget -qO- https://packages.mozilla.org/apt/repo-signing-key.gpg \
      | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc >/dev/null
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
      | sudo tee /etc/apt/sources.list.d/mozilla.list >/dev/null
    echo -e "Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000" \
      | sudo tee /etc/apt/preferences.d/mozilla >/dev/null

    # VS Code
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
      | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" \
      | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null

    sudo apt update
    sudo apt install -y firefox code
}

# ----------------------------------------
# 🔧 EXECUÇÃO PRINCIPAL
# ----------------------------------------
gerar_fstab
setup_basico
optimize_dev_packages
optimize_imagemagick
optimize_ufw
optimize_tlp
optimize_preload
optimize_intel_firmware
optimize_vulkan_mesa
optimize_gamemode
optimize_kernel_tweaks
optimize_numa
faz_o_urro

```
