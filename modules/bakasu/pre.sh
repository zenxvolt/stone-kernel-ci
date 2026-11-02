#!/bin/sh
# Dijalankan di root tree kernel (dipanggil scripts/apply-modules.sh).
# Memasang BakaSU lewat setup.sh milik BakaSU: clone ./KernelSU, symlink
# drivers/kernelsu, lalu menambah baris di drivers/Makefile dan drivers/Kconfig.
#
# Env: BAKASU_REF            branch/tag/commit (default: main)
#      BAKASU_SETUP_SCRIPT   path setup.sh lokal (opsional, untuk uji offline)
set -eu
REF="${BAKASU_REF:-main}"

# Bersihkan sisa KernelSU bila fork kamu membawanya (stone upstream tidak).
rm -rf techpack/KernelSU drivers/kernelsu KernelSU
[ -f techpack/Kconfig ] && sed -i '\#techpack/KernelSU/kernel/Kconfig#d' techpack/Kconfig

SETUP="${BAKASU_SETUP_SCRIPT:-}"
if [ -z "$SETUP" ]; then
	SETUP="$(mktemp)"
	curl -fsSL "https://raw.githubusercontent.com/Baka-SU/BakaSU/${REF}/kernel/setup.sh" -o "$SETUP"
fi
sh "$SETUP" "$REF"

ls -l drivers/kernelsu
git -C KernelSU log -1 --format='BakaSU commit: %h %s'
