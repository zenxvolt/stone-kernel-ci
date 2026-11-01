#!/usr/bin/env bash
# Membandingkan out/.config akhir dengan semua fragmen yang diminta.
# Fragmen wajib (kernel.config)   : beda satu saja -> build gagal.
# Fragmen opsional (optional.config, EXTRA_CONFIG) : beda -> hanya peringatan.
#
# Pakai : FEATURES="..." scripts/verify-config.sh <folder kernel>
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

KDIR=${1:?pakai: verify-config.sh <folder kernel>}
cd "$KDIR"
[ -f out/.config ] || die "out/.config tidak ada, jalankan make-config.sh dulu"

errors=0
warnings=0

# check_fragment <file> <error|warning>. Penghitung global, jadi tidak boleh dipanggil
# di dalam pipe atau $( ).
check_fragment() {
  local frag=$1 level=$2 line sym want have
  while IFS= read -r line; do
    case $line in
      CONFIG_*=*)                sym=${line%%=*}; want=${line#*=} ;;
      "# CONFIG_"*" is not set") sym=${line#\# }; sym=${sym%% *}; want=n ;;
      *) continue ;;
    esac
    have=$(grep -m1 "^${sym}=" out/.config | cut -d= -f2- || true)
    [ -n "$have" ] || have=n
    if [ "$have" != "$want" ]; then
      echo "::$level::$(basename "$(dirname "$frag")")/$(basename "$frag"): ${sym} diminta '${want}', hasil akhir '${have}'"
      if [ "$level" = error ]; then errors=$((errors + 1)); else warnings=$((warnings + 1)); fi
    fi
  done < "$frag"
}

while read -r frag; do
  [ -n "$frag" ] && check_fragment "$frag" error
done < <(required_fragments)

while read -r frag; do
  [ -n "$frag" ] && check_fragment "$frag" warning
done < <(optional_fragments)

if [ "$errors" -gt 0 ]; then
  echo "::error::$errors opsi wajib tidak masuk ke .config akhir (biasanya dependensi Kconfig tidak terpenuhi)"
  exit 1
fi
log "semua opsi wajib terverifikasi di out/.config ($warnings opsi opsional tidak masuk)"
