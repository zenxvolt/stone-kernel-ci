#!/usr/bin/env bash
# prepare_tree.sh <kernel-dir>
# Applies the selected features to the source tree and writes the list of Kconfig
# fragments to <kernel-dir>/.ci-frags. Controlled by environment variables:
#   ENABLE_BACKPORTS ENABLE_DROIDSPACES ENABLE_NETWORK ENABLE_SYSTEMD
#   ENABLE_FIREWALL ENABLE_BAKASU  (0/1)   KABI_VARIANT  BAKASU_REF
set -euo pipefail
K="$(cd "$1" && pwd)"
CI="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${ENABLE_BACKPORTS:=0}" "${ENABLE_DROIDSPACES:=0}" "${ENABLE_NETWORK:=0}"
: "${ENABLE_SYSTEMD:=0}" "${ENABLE_FIREWALL:=0}" "${ENABLE_BAKASU:=0}"
: "${KABI_VARIANT:=6_7_8}" "${BAKASU_REF:=main}"

frags=()

if [ "$ENABLE_SYSTEMD" = 1 ]; then
  echo "== systemd 258+ backports (statx mnt_id/mount_root, utimensat, faccessat2)"
  # close_range already exists in the 5.4.302 stone tree (probe: yes), so only 1-4.
  "$CI/scripts/apply_patches.sh" "$K" "$CI"/patches/systemd-backports/000[1-4]-*.patch
  frags+=("$CI/config/systemd.config")
fi

if [ "$ENABLE_DROIDSPACES" = 1 ]; then
  echo "== Droidspaces kABI padding (variant $KABI_VARIANT) + mqueue"
  "$CI/scripts/apply_patches.sh" "$K" \
    "$CI/patches/droidspaces-kabi/001-sysvipc-kabi-${KABI_VARIANT}.patch" \
    "$CI/patches/droidspaces-kabi/002-mqueue-kabi.patch"
  frags+=("$CI/config/droidspaces.config")
  [ "$ENABLE_FIREWALL" = 1 ] && frags+=("$CI/config/firewall.config")
fi

if [ "$ENABLE_NETWORK" = 1 ]; then
  echo "== macvlan + IPv6 NAT"
  frags+=("$CI/config/network.config")
fi

if [ "$ENABLE_BAKASU" = 1 ]; then
  echo "== BakaSU ($BAKASU_REF), manual hook"
  (cd "$K" && curl -fsSL https://raw.githubusercontent.com/Baka-SU/BakaSU/main/kernel/setup.sh | bash -s "$BAKASU_REF")
  python3 "$CI/scripts/bakasu_hooks.py" "$K"
  echo "BakaSU commit: $(git -C "$K/KernelSU" rev-parse --short=12 HEAD)"
  frags+=("$CI/config/bakasu.config")
fi

printf '%s\n' "${frags[@]:-}" > "$K/.ci-frags"
echo "fragments: ${frags[*]:-<none>}"
