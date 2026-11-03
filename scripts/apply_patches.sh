#!/usr/bin/env bash
# apply_patches.sh <kernel-dir> <patch>...
# Applies each patch with git apply. A patch that is already in the tree is
# skipped, a patch that fits neither way fails the run.
set -euo pipefail
K="$1"; shift
cd "$K"
for p in "$@"; do
  n="$(basename "$p")"
  if git apply --check "$p" 2>/dev/null; then
    git apply "$p"; echo "[+] applied  $n"
  elif git apply --check -R "$p" 2>/dev/null; then
    echo "[=] already in tree  $n"
  else
    echo "[!] DOES NOT APPLY  $n"; git apply --check "$p" || true; exit 1
  fi
done
