#!/bin/bash

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
