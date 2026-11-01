#!/usr/bin/env bash
# Menyiapkan source kernel: untuk tiap fitur aktif jalankan setup.sh (kalau ada)
# lalu terapkan patch di features/<fitur>/patches/.
#
# Pakai : FEATURES="droidspaces bakasu" scripts/prepare-tree.sh <folder kernel>
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

KDIR=${1:?pakai: prepare-tree.sh <folder kernel>}
cd "$KDIR"

apply_dir() {
  local p
  for p in "$1"/*.patch; do
    [ -e "$p" ] || continue
    if git apply --check --whitespace=nowarn "$p" 2>/dev/null; then
      git apply --whitespace=nowarn "$p"
      echo "applied  $(basename "$p")"
    elif git apply -R --check --whitespace=nowarn "$p" 2>/dev/null; then
      # source kernel sudah memuat perubahan ini (mis. setelah sinkron dengan upstream)
      echo "already present, skipped  $(basename "$p")"
    else
      echo "::error::patch tidak bisa diterapkan: $(basename "$p")"
      git apply --check --whitespace=nowarn "$p" || true
      exit 1
    fi
  done
}

if [ -z "${FEATURES:-}" ]; then
  log "tidak ada fitur aktif, source kernel dibiarkan apa adanya"
  exit 0
fi

for f in $FEATURES; do
  [ -f "$FEATURES_DIR/$f/feature.conf" ] || die "fitur tidak dikenal: $f"
  log "fitur: $f  ($(feature_get "$f" FEATURE_DESC))"
  [ -f "$FEATURES_DIR/$f/setup.sh" ] && bash "$FEATURES_DIR/$f/setup.sh"
  [ -d "$FEATURES_DIR/$f/patches" ] && apply_dir "$FEATURES_DIR/$f/patches"
done
exit 0
