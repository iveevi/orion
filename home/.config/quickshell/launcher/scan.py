import os
import re
import sys
from pathlib import Path
from typing import List, Optional, Tuple

THEMES = ["Colloid-Dark", "hicolor", "breeze", "Adwaita"]
SUFFIXES = [".svg", ".svgz", ".png"]
FIELD_CODES = re.compile(r" ?(@@[uU]?|%[fFuUdDnNickvm])")
SIZE_IN_PATH = re.compile(r"/(\d+)(?:x\d+)?/")


def data_dirs() -> List[Path]:
    raw = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
    dirs = [Path(part) for part in raw.split(":") if part]
    dirs.append(Path.home() / ".local/share")
    return dirs


def icon_roots() -> List[Path]:
    roots = [Path.home() / ".icons"]
    roots.extend(directory / "icons" for directory in data_dirs())
    return roots


def rank(path: Path) -> Tuple[int, int]:
    text = str(path)
    if "scalable" in text:
        return (1, 1024)
    match = SIZE_IN_PATH.search(text)
    return (1, int(match.group(1))) if match else (0, 0)


def candidates(theme_dir: Path, name: str) -> List[Path]:
    wanted = {name + suffix for suffix in SUFFIXES}
    found = []
    for parent, _, files in os.walk(theme_dir, followlinks=True):
        if "/apps/" not in parent + "/":
            continue
        found.extend(Path(parent) / f for f in files if f in wanted)
    return found


def resolve(name: str) -> str:
    if not name:
        return ""
    if name.startswith("/"):
        return name if Path(name).exists() else ""
    for theme in THEMES:
        for root in icon_roots():
            theme_dir = root / theme
            if not theme_dir.is_dir():
                continue
            found = candidates(theme_dir, name)
            if found:
                return str(max(found, key=rank))
    for root in icon_roots():
        for directory in (root.parent / "pixmaps", root):
            for suffix in SUFFIXES:
                candidate = directory / (name + suffix)
                if candidate.exists():
                    return str(candidate)
    return ""


def parse(path: Path) -> Optional[Tuple[str, str, str]]:
    name = ""
    command = ""
    icon = ""
    inside = False
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("["):
            inside = line == "[Desktop Entry]"
            continue
        if not inside or "=" not in line:
            continue
        key, _, value = line.partition("=")
        if key in ("NoDisplay", "Hidden") and value == "true":
            return None
        if key == "Name" and not name:
            name = value
        elif key == "Exec" and not command:
            command = value
        elif key == "Icon" and not icon:
            icon = value
    if not name or not command:
        return None
    return (name, FIELD_CODES.sub("", command).strip(), icon)


def main() -> None:
    entries = {}
    for directory in data_dirs():
        for path in sorted((directory / "applications").glob("*.desktop")):
            entry = parse(path)
            if entry:
                entries[entry[0]] = entry
    for name, command, icon in sorted(entries.values()):
        sys.stdout.write("\t".join([name, command, resolve(icon)]) + "\n")


main()
