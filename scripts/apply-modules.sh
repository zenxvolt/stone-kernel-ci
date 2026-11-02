#!/usr/bin/env bash
# Menerapkan modul terpilih ke tree kernel: pre.sh -> patch -> kumpulkan fragment config.
#
# Pakai:  scripts/apply-modules.sh <kernel_dir> <modul>
#   <modul> = "bakasu,droidspaces" | "all" | "none"
# Keluaran di $CI_META_DIR (default: <repo>/.build-meta):
#   selected.txt  modul yang dipakai (setelah REQUIRES dipenuhi)
#   fragments.txt fragment config, urut penerapan
#   want.txt / want_not.txt  simbol yang harus =y / harus mati (untuk verify-config.sh)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KDIR="$(cd "${1:?usage: $0 <kernel_dir> <modules>}" && pwd)"
REQ="${2:-none}"
META="${CI_META_DIR:-$ROOT/.build-meta}"
mkdir -p "$META"
: > "$META/selected.txt"; : > "$META/fragments.txt"; : > "$META/want.txt"; : > "$META/want_not.txt"

die() { echo "::error::$*" >&2; exit 1; }
conf_get() { # modul VAR -> nilai variabel dari module.conf (di subshell, tanpa bocor)
	( DESC=""; REQUIRES=""; CONFLICTS=""; WANT=""; WANT_NOT=""
	  . "$ROOT/modules/$1/module.conf"; eval "printf '%s' \"\${$2}\"" )
}

mapfile -t ORDER < <(sed -e 's/#.*//' -e 's/[[:space:]]//g' -e '/^$/d' "$ROOT/modules/order.txt")

declare -A SEL=()
case "$REQ" in
	none|"") ;;
	all) for m in "${ORDER[@]}"; do SEL[$m]=1; done ;;
	*)
		IFS=',' read -ra items <<< "$REQ"
		for m in "${items[@]}"; do
			m="${m//[[:space:]]/}"; [ -n "$m" ] || continue
			[ -f "$ROOT/modules/$m/module.conf" ] || die "modul '$m' tidak ada (tersedia: ${ORDER[*]})"
			SEL[$m]=1
		done ;;
esac

# Penuhi REQUIRES secara transitif
changed=1
while [ "$changed" = 1 ]; do
	changed=0
	for m in "${!SEL[@]}"; do
		for r in $(conf_get "$m" REQUIRES); do
			[ -f "$ROOT/modules/$r/module.conf" ] || die "modul '$m' butuh '$r' yang tidak ada"
			if [ -z "${SEL[$r]:-}" ]; then SEL[$r]=1; changed=1; echo "note: '$m' membutuhkan '$r', ikut diaktifkan"; fi
		done
	done
done
for m in "${!SEL[@]}"; do
	for c in $(conf_get "$m" CONFLICTS); do
		[ -z "${SEL[$c]:-}" ] || die "modul '$m' bentrok dengan '$c'"
	done
done

# skip-if: kembalikan 0 (dan alasan di stdout) bila fitur patch sudah ada di tree
probe_skip() { # modul nama_patch
	local f="$ROOT/modules/$1/skip-if.txt" pn file re
	[ -f "$f" ] || return 1
	while IFS='|' read -r pn file re; do
		[ "$pn" = "$2" ] || continue
		if [ -f "$KDIR/$file" ] && grep -qE -- "$re" "$KDIR/$file"; then
			echo "fitur sudah ada: $file ~ $re"; return 0
		fi
	done < <(grep -v '^[[:space:]]*#' "$f" | sed '/^[[:space:]]*$/d')
	return 1
}

apply_one() { # path_patch  skip_reason(kosong bila tidak di-skip)
	local p="$1" name; name="$(basename "$1")"
	if [ -n "${2:-}" ]; then echo "skip     $name ($2)"; return; fi
	if git -C "$KDIR" apply --check --whitespace=nowarn "$p" 2>/dev/null; then
		git -C "$KDIR" apply --whitespace=nowarn "$p"; echo "applied  $name"
	elif git -C "$KDIR" apply -R --check --whitespace=nowarn "$p" 2>/dev/null; then
		echo "present  $name (sudah ada di tree)"
	else
		echo "::error::patch gagal diterapkan: $name" >&2
		git -C "$KDIR" apply --check --whitespace=nowarn "$p" 2>&1 | head -20 >&2 || true
		exit 1
	fi
}

for m in "${ORDER[@]}"; do
	[ -n "${SEL[$m]:-}" ] || continue
	echo "== modul: $m - $(conf_get "$m" DESC)"
	echo "$m" >> "$META/selected.txt"

	if [ -f "$ROOT/modules/$m/pre.sh" ]; then
		echo "-- pre.sh"
		( cd "$KDIR" && sh "$ROOT/modules/$m/pre.sh" )
	fi

	# Putuskan skip untuk semua patch modul ini sebelum ada yang diterapkan
	shopt -s nullglob
	patches=( "$ROOT/modules/$m/patches/"*.patch )
	reasons=()
	for p in "${patches[@]}"; do reasons+=( "$(probe_skip "$m" "$(basename "$p")" || true)" ); done
	for i in "${!patches[@]}"; do apply_one "${patches[$i]}" "${reasons[$i]}"; done

	for c in "$ROOT/modules/$m/"*.config; do echo "$c" >> "$META/fragments.txt"; done
	for s in $(conf_get "$m" WANT);     do echo "$s" >> "$META/want.txt"; done
	for s in $(conf_get "$m" WANT_NOT); do echo "$s" >> "$META/want_not.txt"; done
	shopt -u nullglob
done

echo "== selesai. modul aktif: $(paste -sd, "$META/selected.txt" || true)"
