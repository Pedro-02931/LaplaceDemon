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
sudo apt install fio -y
LOGFILE="/var/vemCaPutinha.storage.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo -e "🧪 Benchmark de Storage - $(date)\n"

PARTICOES=(
  "/" "/boot" "/boot/efi" "/home" "/usr" "/var" "/tmp" "/working" "/sensory/tmp" "/dev/shm"
)

for MOUNT in "${PARTICOES[@]}"; do
    if mountpoint -q "$MOUNT"; then
        echo -e "\n🔹 Testando: $MOUNT"
        TESTDIR="$MOUNT/.iotest"
        mkdir -p "$TESTDIR"

        echo "  🔄 Limpando cache (sync + drop_caches)"
        sync && echo 3 | sudo tee /proc/sys/vm/drop_caches

        echo "  📥 Escrita sequencial (dd):"
        dd if=/dev/zero of="$TESTDIR/test1.img" bs=64M count=16 oflag=direct status=progress

        echo "  📤 Leitura sequencial (dd):"
        dd if="$TESTDIR/test1.img" of=/dev/null bs=64M iflag=direct status=progress

        echo "  🎲 I/O aleatório com fio:"
        fio --name=random_rw_test --directory="$TESTDIR" --numjobs=1 --iodepth=4 \
            --size=128M --rw=randrw --rwmixread=70 --bs=4k --direct=1 --time_based --runtime=10s \
            --group_reporting

        echo "  🧹 Limpando arquivos temporários..."
        rm -rf "$TESTDIR"
    else
        echo -e "\n⚠️  Ponto de montagem não encontrado: $MOUNT"
    fi
done

echo -e "\n✅ Benchmark concluído em $(date)"
