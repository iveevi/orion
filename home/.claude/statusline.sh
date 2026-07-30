#!/bin/bash

input=$(cat)

dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir')
used=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // 0')

short_dir=$dir
case "$short_dir" in
    "$HOME"*) short_dir="~${short_dir#"$HOME"}" ;;
esac

out=$(printf '\033[01;34m%s\033[0m' "$short_dir")

branch=$(git -C "$dir" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
    || git -C "$dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null)

if [ -n "$branch" ]; then
    read -r added modified deleted untracked <<<"$(
        git -C "$dir" --no-optional-locks status --porcelain 2>/dev/null | awk '
            {
                x = substr($0, 1, 1)
                y = substr($0, 2, 1)
                if (x y == "??") u++
                else if (x == "A" || y == "A") a++
                else if (x == "D" || y == "D") d++
                else m++
            }
            END { printf "%d %d %d %d", a, m, d, u }'
    )"

    if [ $((added + modified + deleted + untracked)) -eq 0 ]; then
        out="$out$(printf ' \033[01;32m%s\033[0m' "$branch")"
    else
        out="$out$(printf ' \033[01;33m%s\033[0m' "$branch")"
        [ "$added" -gt 0 ] && out="$out$(printf ' \033[32m+%d\033[0m' "$added")"
        [ "$modified" -gt 0 ] && out="$out$(printf ' \033[33m~%d\033[0m' "$modified")"
        [ "$deleted" -gt 0 ] && out="$out$(printf ' \033[31m-%d\033[0m' "$deleted")"
        [ "$untracked" -gt 0 ] && out="$out$(printf ' \033[90m?%d\033[0m' "$untracked")"
    fi
fi

if [ "$used" -ge 80 ]; then
    color='01;31'
elif [ "$used" -ge 50 ]; then
    color='33'
else
    color='90'
fi

printf '%s \033[%sm%s%%\033[0m' "$out" "$color" "$used"
