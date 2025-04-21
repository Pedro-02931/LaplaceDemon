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

LOGFILE="/var/vemCaPutinha.ssd_info.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo -e "\n📦 COLETA COMPLETA DO SSD - $(date)\n"

# Detecta o disco principal com partição montada em /
DISCO=$(lsblk -no PKNAME,MOUNTPOINT | grep ' /$' | awk '{print $1}' | head -n1)

if [[ -z "$DISCO" ]]; then
    echo "❌ Erro: disco principal não detectado automaticamente."
    exit 1
fi

DISCO_PATH="/dev/$DISCO"
echo "📍 Disco principal detectado: $DISCO_PATH"

echo -e "\n🔎 Informações básicas do dispositivo:"
lsblk -o NAME,SIZE,ROTA,TYPE,MOUNTPOINT,LABEL,UUID,FSTYPE

echo -e "\n📑 Informações detalhadas (udevadm):"
udevadm info --query=all --name="$DISCO_PATH"

echo -e "\n🧠 Informações SMART (health):"
sudo smartctl -d sat -a "$DISCO_PATH"

echo -e "\n🚗 Informações do driver:"
if [[ -e /dev/nvme0 ]]; then
    sudo nvme list
    sudo nvme smart-log "$DISCO_PATH"
else
    if ! command -v hdparm &> /dev/null; then
        echo "⚠️ hdparm não instalado. Instalando automaticamente..."
        sudo apt-get update && sudo apt-get install -y hdparm
    fi
    sudo hdparm -I "$DISCO_PATH"
fi

echo -e "\n📈 Atributos básicos de desempenho (hdparm):"
sudo hdparm -tT "$DISCO_PATH"

echo -e "\n📊 Partições e tipo de FS:"
lsblk -f "$DISCO_PATH"

echo -e "\n🧹 Suporte a TRIM:"
sudo fstrim -v /

echo -e "\n🌡️  Temperatura atual (se suportado):"
if [[ -e /dev/nvme0 ]]; then
    sudo nvme smart-log "$DISCO_PATH" | grep -i temperature
else
    sudo smartctl -A "$DISCO_PATH" | grep -i Temperature
fi

echo -e "\n⚙️  Tecnologias suportadas (TRIM, NCQ, etc):"
sudo hdparm -I "$DISCO_PATH" | grep -Ei "TRIM|NCQ|Native Command"

echo -e "\n✅ Coleta finalizada com sucesso em $(date)"
