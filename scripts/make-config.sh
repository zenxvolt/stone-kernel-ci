#!/usr/bin/env bash
# Membuat out/.config: defconfig bawaan stone + fragmen tiap fitur aktif.
#
# Pakai : FEATURES="..." [LTO=stock|off] [EXTRA_CONFIG="DRM_VGEM=y ..."] \
#         scripts/make-config.sh <folder kernel>
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

KDIR=${1:?pakai: make-config.sh <folder kernel>}
cd "$KDIR"
DEFCONFIG=${DEFCONFIG:-moonstone_defconfig}

mkdir -p out
rm -f out/extra.config

# EXTRA_CONFIG: "NAMA=nilai" dipisah spasi atau koma, awalan CONFIG_ boleh dihilangkan.
# "NAMA=n" berarti dimatikan.
for t in $(echo "${EXTRA_CONFIG:-}" | tr ',' ' '); do
  name=${t%%=*}; val=${t#*=}
  [ "$name" != "$t" ] || die "EXTRA_CONFIG: '$t' bukan format NAMA=nilai"
  name=CONFIG_${name#CONFIG_}
  if [ "$val" = n ]; then echo "# $name is not set"; else echo "$name=$val"; fi
done > out/extra.config
[ -s out/extra.config ] || rm -f out/extra.config

log "defconfig: $DEFCONFIG"
"${KMAKE[@]}" "$DEFCONFIG"

mapfile -t FRAGS < <(required_fragments; optional_fragments)
log "fragmen yang digabung:"
printf '   %s\n' "${FRAGS[@]}"
scripts/kconfig/merge_config.sh -m -O out out/.config "${FRAGS[@]}" >/dev/null
"${KMAKE[@]}" olddefconfig

# Versi kernel yang deterministik: tanpa -g<hash>/-dirty dari git.
printf -- '%s' "${LOCALVERSION_SUFFIX--stone-ci}" > .scmversion
"${KMAKE[@]}" -s kernelrelease
