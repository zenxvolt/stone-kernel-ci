#!/usr/bin/env bash
# Dijalankan dari dalam folder source kernel. Source stone tidak membawa KernelSU,
# jadi tidak ada yang perlu dihapus; cukup pasang BakaSU lewat setup.sh miliknya:
# meng-clone ./KernelSU, membuat symlink drivers/kernelsu, dan menyambungkan
# drivers/Makefile serta drivers/Kconfig.
set -eux
REF=${BAKASU_REF:-main}
TMP=$(mktemp -d)
curl -fsSL "https://raw.githubusercontent.com/Baka-SU/BakaSU/${REF}/kernel/setup.sh" -o "$TMP/bakasu-setup.sh"
sh "$TMP/bakasu-setup.sh" "$REF"
rm -rf "$TMP"
ls -l drivers/kernelsu
git -C KernelSU log -1 --format='BakaSU commit: %h %s'
