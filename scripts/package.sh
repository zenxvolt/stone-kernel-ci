#!/usr/bin/env bash
# Membuat zip AnyKernel3 yang hanya mengganti Image di partisi boot.
#
# Pakai : FEATURES="..." scripts/package.sh <folder kernel> <folder output>
# Mencetak nama zip di baris terakhir.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

KDIR=$(cd "${1:?pakai: package.sh <folder kernel> <folder output>}" && pwd)
OUTDIR=$(mkdir -p "${2:?}" && cd "$2" && pwd)
IMAGE=$KDIR/out/arch/arm64/boot/Image
[ -f "$IMAGE" ] || die "Image tidak ada: $IMAGE"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

git clone -q --depth=1 https://github.com/osm0sis/AnyKernel3 "$WORK/ak3"
rm -rf "$WORK/ak3/.git" "$WORK/ak3/.github" "$WORK/ak3/README.md"

NAMES=${FEATURES:-}
sed "s|@FEATURES@|${NAMES:-stock}|" "$CI_ROOT/anykernel/anykernel.sh" > "$WORK/ak3/anykernel.sh"
# Hanya Image. Jangan menaruh file 'dtb' di zip: AnyKernel3 lalu ikut menyentuh vendor_boot.
cp "$IMAGE" "$WORK/ak3/Image"

TAG=$(echo "${NAMES:-stock}" | tr ' ' '-')
ZIP="stone-${TAG}-$(date +%Y%m%d-%H%M).zip"
(cd "$WORK/ak3" && zip -qr9 "$OUTDIR/$ZIP" . -x '*.placeholder')
echo "$ZIP"
