#!/usr/bin/env bash
# Memeriksa .config akhir terhadap daftar WANT / WANT_NOT milik modul aktif.
# Pakai: scripts/verify-config.sh <path .config>
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CFG="${1:?usage: $0 <.config>}"
META="${CI_META_DIR:-$ROOT/.build-meta}"
fail=0

while read -r s; do
	[ -n "$s" ] || continue
	if grep -q "^CONFIG_${s}=y" "$CFG"; then echo "ok       CONFIG_${s}"
	else echo "MISSING  CONFIG_${s}"; fail=1; fi
done < "$META/want.txt"

while read -r s; do
	[ -n "$s" ] || continue
	if grep -qE "^CONFIG_${s}=[ym]" "$CFG"; then echo "MUST BE OFF  CONFIG_${s}"; fail=1
	else echo "ok       CONFIG_${s} off"; fi
done < "$META/want_not.txt"

exit $fail
