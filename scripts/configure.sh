#!/usr/bin/env bash
# defconfig -> merge fragment modul -> configs/extra.config -> fragment tambahan -> olddefconfig
#
# Pakai: scripts/configure.sh <kernel_dir> <defconfig> [fragment tambahan...]
# Hasil: <kernel_dir>/out/.config
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KDIR="$(cd "${1:?usage: $0 <kernel_dir> <defconfig> [fragments...]}" && pwd)"
DEFCONFIG="${2:?defconfig kosong}"; shift 2
META="${CI_META_DIR:-$ROOT/.build-meta}"
# shellcheck source=env.sh
. "$ROOT/scripts/env.sh"

cd "$KDIR"
kmake "$DEFCONFIG"

FR=()
if [ -f "$META/fragments.txt" ]; then
	while IFS= read -r f; do [ -n "$f" ] && FR+=( "$f" ); done < "$META/fragments.txt"
fi
[ -f "$ROOT/configs/extra.config" ] && FR+=( "$ROOT/configs/extra.config" )
for f in "$@"; do FR+=( "$(readlink -f "$f")" ); done

if [ "${#FR[@]}" -gt 0 ]; then
	echo "== merge fragment:"; printf '   %s\n' "${FR[@]}"
	scripts/kconfig/merge_config.sh -m -O out out/.config "${FR[@]}" > "$META/merge.log" 2>&1 || { cat "$META/merge.log"; exit 1; }
	grep -E "Value of CONFIG_.* is redefined" "$META/merge.log" | head -40 || true
fi
kmake olddefconfig
