#!/usr/bin/env bash
# abi_diff.sh <baseline Module.symvers> <custom Module.symvers> [report.md]
# Lists exported symbols whose CRC changed. Stock vendor modules that import any
# of them are rejected by CONFIG_MODVERSIONS -> boot stalls at the logo.
set -euo pipefail
export LC_ALL=C
a="$1"; b="$2"; out="${3:-abi-report.md}"
t="$(mktemp -d)"
awk -F'\t' '{print $2"\t"$1}' "$a" | sort > "$t/a"
awk -F'\t' '{print $2"\t"$1}' "$b" | sort > "$t/b"
join -t $'\t' "$t/a" "$t/b" | awk -F'\t' '$2!=$3{print $1"\t"$2"\t"$3}' > "$t/changed"
cut -f1 "$t/a" > "$t/ka"; cut -f1 "$t/b" > "$t/kb"
comm -23 "$t/ka" "$t/kb" > "$t/removed"
comm -13 "$t/ka" "$t/kb" > "$t/added"
nc=$(wc -l < "$t/changed"); nr=$(wc -l < "$t/removed"); na=$(wc -l < "$t/added")
{
  echo "# ABI report (baseline vs custom)"
  echo
  echo "- exported symbols baseline: $(wc -l < "$t/a")"
  echo "- exported symbols custom:   $(wc -l < "$t/b")"
  echo "- **CRC changed: $nc**   removed: $nr   added: $na"
  echo
  if [ "$nc" -eq 0 ] && [ "$nr" -eq 0 ]; then
    echo "No existing export changed. Stock vendor modules should keep loading."
  else
    echo "Existing exports changed. Vendor modules importing them will fail to load."
    echo "Try another kabi_variant, or drop the feature that moved the struct."
    echo
    echo '```'; echo "symbol  baseline_crc  custom_crc"; head -n 200 "$t/changed"; echo '```'
    [ "$nr" -gt 0 ] && { echo; echo "Removed (first 50):"; echo '```'; head -n 50 "$t/removed"; echo '```'; }
  fi
} | tee "$out"
[ "$nc" -eq 0 ] && [ "$nr" -eq 0 ]
