# Helper bersama untuk skrip CI. Di-source, bukan dijalankan langsung.

CI_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FEATURES_DIR=$CI_ROOT/features

log()  { echo "== $*"; }
warn() { echo "::warning::$*" >&2; }
die()  { echo "::error::$*" >&2; exit 1; }

# Satu-satunya tempat argumen make didefinisikan, supaya defconfig, olddefconfig
# dan build memakai toolchain yang sama persis. Dijalankan dari dalam folder kernel.
KMAKE=(make O=out ARCH=arm64 LLVM=1 CC=clang
       CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
       KBUILD_BUILD_USER=github-actions KBUILD_BUILD_HOST=stone-kernel-ci)

list_features() {
  local d
  for d in "$FEATURES_DIR"/*/; do
    [ -f "${d}feature.conf" ] && basename "$d"
  done
}

# feature_get <fitur> <VARIABEL>  ->  isi VARIABEL dari features/<fitur>/feature.conf
feature_get() {
  ( FEATURE_DESC=""; FEATURE_REQUIRES=""; FEATURE_ORDER=50
    . "$FEATURES_DIR/$1/feature.conf"
    printf '%s' "${!2}" )
}

# resolve_features "a,b c"  ->  satu fitur per baris, urut FEATURE_ORDER,
# dependensi (FEATURE_REQUIRES) ditambahkan otomatis dengan peringatan.
resolve_features() {
  local want=() f r changed=1
  for f in $(echo "${1:-}" | tr ',' ' '); do want+=("$f"); done
  while [ "$changed" = 1 ]; do
    changed=0
    for f in "${want[@]}"; do
      [ -f "$FEATURES_DIR/$f/feature.conf" ] \
        || die "fitur tidak dikenal: $f (tersedia: $(list_features | tr '\n' ' '))"
      for r in $(feature_get "$f" FEATURE_REQUIRES); do
        case " ${want[*]} " in
          *" $r "*) ;;
          *) warn "$f membutuhkan $r, jadi $r ikut diaktifkan"; want+=("$r"); changed=1;;
        esac
      done
    done
  done
  for f in "${want[@]}"; do
    echo "$(feature_get "$f" FEATURE_ORDER) $f"
  done | sort -u -k1,1n -k2,2 | awk '{print $2}'
}

# Fragmen config yang WAJIB berlaku (gagal kalau tidak masuk ke .config akhir).
required_fragments() {
  local f
  echo "$CI_ROOT/configs/ci.config"
  [ "${LTO:-stock}" = off ] && echo "$CI_ROOT/configs/lto-off.config"
  for f in $FEATURES; do
    [ -f "$FEATURES_DIR/$f/kernel.config" ] && echo "$FEATURES_DIR/$f/kernel.config"
  done
  return 0
}

# Fragmen opsional: ikut digabung, tapi yang tidak masuk hanya jadi peringatan.
optional_fragments() {
  local f
  for f in $FEATURES; do
    [ -f "$FEATURES_DIR/$f/optional.config" ] && echo "$FEATURES_DIR/$f/optional.config"
  done
  [ -f out/extra.config ] && echo "$PWD/out/extra.config"
  return 0
}
