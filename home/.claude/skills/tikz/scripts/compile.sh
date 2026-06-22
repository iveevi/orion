#!/usr/bin/env bash
set -uo pipefail

TEX="${1:?usage: compile.sh <file.tex>}"
[ -f "$TEX" ] || { echo "ERROR: no such file: $TEX" >&2; exit 2; }

DIR="$(cd "$(dirname "$TEX")" && pwd)"
BASE="$(basename "$TEX" .tex)"
ENGINE="${TIKZ_ENGINE:-pdflatex}"
DPI="${TIKZ_DPI:-300}"
LOG="$DIR/$BASE.build.log"

command -v "$ENGINE"   >/dev/null 2>&1 || { echo "ERROR: $ENGINE not found"   >&2; exit 127; }
command -v pdftoppm    >/dev/null 2>&1 || { echo "ERROR: pdftoppm not found"  >&2; exit 127; }

cd "$DIR"
"$ENGINE" -interaction=nonstopmode -halt-on-error "$BASE.tex" >"$LOG" 2>&1
STATUS=$?

if [ $STATUS -ne 0 ] || [ ! -f "$BASE.pdf" ]; then
  echo "COMPILE_FAILED"
  echo "--- errors ($LOG) ---"
  sed -n '/^! /,$p' "$LOG" | head -n 40
  exit 1
fi

pdftoppm -png -r "$DPI" -singlefile "$BASE.pdf" "$BASE" >/dev/null 2>&1 \
  || { echo "RASTER_FAILED"; exit 3; }

echo "COMPILE_OK $DIR/$BASE.png"
