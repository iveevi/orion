#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path

from rich.console import Console
from rich.text import Text

MODES = {
    "plan": ("blue", "⏸ plan"),
    "acceptEdits": ("green", "⏵⏵ accept edits"),
    "bypassPermissions": ("red", "⏵⏵ bypass"),
    "dangerously-skip-permissions": ("red", "⏵⏵ bypass"),
}


def bubbles(items):
    t = Text()
    for i, (c, label) in enumerate(items):
        if i:
            t.append(" ")
        t.append(f" {label.strip()} ", style=f"reverse {c}")
    return t


GRADIENT = ((0x00, 0xAF, 0x5F), (0xD7, 0xAF, 0x00), (0xD7, 0x30, 0x30))


def heat(pct):
    p = max(0.0, min(100.0, float(pct))) / 100
    lo, hi, f = (GRADIENT[0], GRADIENT[1], p / 0.6) if p < 0.6 else (GRADIENT[1], GRADIENT[2], (p - 0.6) / 0.4)
    return "#" + "".join(f"{round(a + (b - a) * f):02x}" for a, b in zip(lo, hi))


def git(dirpath, *args):
    try:
        r = subprocess.run(["git", "-C", dirpath, "--no-optional-locks", *args],
                           capture_output=True, text=True, timeout=2)
    except (OSError, subprocess.SubprocessError):
        return ""
    return r.stdout.strip() if r.returncode == 0 else ""


def branch_bubble(dirpath):
    name = git(dirpath, "symbolic-ref", "--short", "HEAD") or git(dirpath, "rev-parse", "--short", "HEAD")
    if not name:
        return None
    counts = {"+": 0, "~": 0, "-": 0, "?": 0}
    for line in git(dirpath, "status", "--porcelain").splitlines():
        x, y = line[:1], line[1:2]
        if x + y == "??":
            counts["?"] += 1
        elif "A" in (x, y):
            counts["+"] += 1
        elif "D" in (x, y):
            counts["-"] += 1
        else:
            counts["~"] += 1
    label = "⎇ " + name + "".join(f" {s}{n}" for s, n in counts.items() if n)
    return ("yellow" if any(counts.values()) else "green"), label


RIGHT_MARGIN = 6


def term_cols():
    fd = None
    try:
        fd = os.open(f"/proc/{os.getppid()}/fd/0", os.O_RDONLY)
        return os.get_terminal_size(fd).columns
    except OSError:
        return 100
    finally:
        if fd is not None:
            os.close(fd)


def main():
    try:
        d = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        d = {}
    cwd = d.get("workspace", {}).get("current_dir") or os.getcwd()
    used = int(d.get("context_window", {}).get("used_percentage") or 0)

    home = str(Path.home())
    short = "~" + cwd[len(home):] if cwd.startswith(home) else cwd

    left = [("blue", short)]
    branch = branch_bubble(cwd)
    if branch:
        left.append(branch)

    right = []
    mode = MODES.get(d.get("permission_mode") or "")
    if mode:
        right.append(mode)
    right.append((heat(used), f"{used}%"))

    cols = term_cols() - RIGHT_MARGIN
    lt, rt = bubbles(left), bubbles(right)
    line = Text.assemble(lt, " " * max(1, cols - lt.cell_len - rt.cell_len), rt)
    Console(width=cols, force_terminal=True, soft_wrap=True).print(line, end="")


main()
