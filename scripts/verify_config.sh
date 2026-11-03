#!/usr/bin/env bash
# verify_config.sh <.config> <fragment>...
# Fails if an option requested by a fragment is not what ended up in .config
# (dependency missing, option renamed, overridden by olddefconfig, ...).
set -uo pipefail
cfg="$1"; shift
bad=0
for f in "$@"; do
  while IFS= read -r line; do
    case "$line" in
      CONFIG_*=*)
        key="${line%%=*}"
        if ! grep -qxF "$line" "$cfg"; then
          got="$(grep -E "^(${key}=|# ${key} is not set)" "$cfg" || echo '<absent>')"
          echo "MISSING  [$(basename "$f")] wanted '$line' got '$got'"; bad=1
        fi ;;
      "# CONFIG_"*" is not set")
        key="$(awk '{print $2}' <<<"$line")"
        if grep -qE "^${key}=" "$cfg"; then
          echo "UNWANTED [$(basename "$f")] $key is enabled"; bad=1
        fi ;;
    esac
  done < "$f"
done
[ "$bad" = 0 ] && echo "config check: all requested options are in .config"
exit "$bad"
