#!/usr/bin/env bash
set -uo pipefail

TYP="${1:?usage: compile.sh <file.typ>}"
[ -f "$TYP" ] || { echo "ERROR: no such file: $TYP" >&2; exit 2; }

DIR="$(cd "$(dirname "$TYP")" && pwd)"
BASE="$(basename "$TYP" .typ)"
DPI="${CETZ_DPI:-300}"
PPI=$(python3 -c "print(int($DPI))" 2>/dev/null || echo "$DPI")
PNG="$DIR/$BASE.png"
LOG="$DIR/$BASE.build.log"

command -v typst >/dev/null 2>&1 || { echo "ERROR: typst not found" >&2; exit 127; }

cd "$DIR"
typst compile --ppi "$PPI" "$BASE.typ" "$BASE.png" >"$LOG" 2>&1
STATUS=$?

if [ $STATUS -ne 0 ] || [ ! -f "$PNG" ]; then
  echo "COMPILE_FAILED"
  echo "--- errors ($LOG) ---"
  sed -n '/error:/,$p' "$LOG" | head -n 40
  [ -s "$LOG" ] || echo "(empty log)"
  head -n 40 "$LOG"
  exit 1
fi

echo "COMPILE_OK $PNG"
