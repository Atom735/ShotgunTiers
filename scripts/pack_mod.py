#!/usr/bin/env python3
"""Build Factorio Mod Portal zip packages from mod folders in this repo."""

from __future__ import annotations

import argparse
import json
import re
import sys
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

EXCLUDE_DIR_NAMES = {
    ".git",
    ".cursor",
    ".vs",
    ".idea",
    "dist",
    "__pycache__",
    "node_modules",
}
EXCLUDE_FILE_NAMES = {
    "Thumbs.db",
    ".DS_Store",
    "desktop.ini",
}
EXCLUDE_FILE_REGEXES = [
    re.compile(r"^README.*\.md$", re.IGNORECASE),
    re.compile(r"^changelog_RU\.txt$", re.IGNORECASE),
    re.compile(r"^\.gitignore$"),
    re.compile(r"^\.gitattributes$"),
    re.compile(r".*\.zip$", re.IGNORECASE),
    re.compile(r".*\.psd$", re.IGNORECASE),
    re.compile(r".*\.blend$", re.IGNORECASE),
    re.compile(r".*\.tmp$", re.IGNORECASE),
]

VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")


def is_excluded(relative: Path) -> bool:
    parts = relative.parts
    if any(part in EXCLUDE_DIR_NAMES for part in parts[:-1]):
        return True
    name = relative.name
    if name in EXCLUDE_FILE_NAMES:
        return True
    return any(pattern.match(name) for pattern in EXCLUDE_FILE_REGEXES)


def load_info(mod_path: Path) -> dict:
    info_path = mod_path / "info.json"
    if not info_path.is_file():
        raise FileNotFoundError(f"Missing info.json in: {mod_path}")
    info = json.loads(info_path.read_text(encoding="utf-8"))
    name = info.get("name")
    version = info.get("version")
    if not name or not version:
        raise ValueError(f"info.json must contain name and version: {info_path}")
    if not VERSION_RE.match(str(version)):
        raise ValueError(f"Invalid version '{version}' in {info_path} (expected X.Y.Z)")
    return info


def pack_mod(mod_path: Path, out_dir: Path) -> Path:
    mod_path = mod_path.resolve()
    info = load_info(mod_path)
    package_id = f"{info['name']}_{info['version']}"
    out_dir.mkdir(parents=True, exist_ok=True)
    zip_path = out_dir / f"{package_id}.zip"
    if zip_path.exists():
        zip_path.unlink()

    count = 0
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for file_path in mod_path.rglob("*"):
            if not file_path.is_file():
                continue
            rel = file_path.relative_to(mod_path)
            if is_excluded(rel):
                continue
            arcname = f"{package_id}/{rel.as_posix()}"
            zf.write(file_path, arcname)
            count += 1

    if count == 0:
        raise RuntimeError(f"No files packed from {mod_path} (everything excluded?)")

    print(f"Packed {count} files -> {zip_path}")
    print(
        f"  name={info['name']} version={info['version']} "
        f"factorio_version={info.get('factorio_version')}"
    )
    return zip_path


def iter_mod_dirs(repo_root: Path) -> list[Path]:
    skip = {".cursor", "scripts", "dist"}
    mods: list[Path] = []
    for path in sorted(repo_root.iterdir()):
        if not path.is_dir() or path.name in skip:
            continue
        if (path / "info.json").is_file():
            mods.append(path)
    return mods


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "mod_dir",
        nargs="?",
        help="Mod folder path (relative to repo root or absolute)",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Pack every top-level folder that contains info.json",
    )
    parser.add_argument(
        "--out",
        default="dist",
        help="Output directory (default: dist)",
    )
    parser.add_argument(
        "--repo-root",
        default=str(REPO_ROOT),
        help="Repository root (default: parent of scripts/)",
    )
    args = parser.parse_args(argv)

    repo_root = Path(args.repo_root).resolve()
    out_dir = Path(args.out)
    if not out_dir.is_absolute():
        out_dir = repo_root / out_dir

    if args.all:
        mods = iter_mod_dirs(repo_root)
        if not mods:
            print(f"No mod folders with info.json found under {repo_root}", file=sys.stderr)
            return 1
        for mod in mods:
            pack_mod(mod, out_dir)
        return 0

    if not args.mod_dir:
        parser.error("Specify mod_dir or --all")

    mod_path = Path(args.mod_dir)
    if not mod_path.is_absolute():
        mod_path = repo_root / mod_path
    if not mod_path.is_dir():
        print(f"Mod directory not found: {mod_path}", file=sys.stderr)
        return 1

    pack_mod(mod_path, out_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
