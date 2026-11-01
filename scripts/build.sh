#!/usr/bin/env bash
# Membangun arch/arm64/boot/Image (tanpa kompresi, sama seperti build bawaan stone).
# DTB tidak dibangun: DTB ada di vendor_boot dan tidak diubah oleh zip ini.
#
# Pakai : scripts/build.sh <folder kernel> [file log]
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

KDIR=${1:?pakai: build.sh <folder kernel> [file log]}
LOG=${2:-$PWD/build.log}
cd "$KDIR"

MK=("${KMAKE[@]}" -j"$(nproc)")
: > "$LOG"

# BakaSU meng-include security/selinux/flask.h dan generated/compile.h tanpa
# mendeklarasikannya sebagai dependensi. Dibuat lebih dulu supaya build paralel
# tidak balapan. Tanpa BakaSU langkah ini tidak berbahaya.
"${MK[@]}" security/selinux/ init/version.o 2>&1 | tee -a "$LOG"

# -k: lanjut setelah error supaya SATU kali jalan menampilkan semua file yang gagal.
"${MK[@]}" -k Image 2>&1 | tee -a "$LOG"

ls -l out/arch/arm64/boot/Image
