#!/usr/bin/env python3
"""Pack and publish/update Factorio mods on the Mod Portal."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

try:
    import requests
except ImportError:  # pragma: no cover
    requests = None  # type: ignore

from pack_mod import REPO_ROOT, iter_mod_dirs, load_info, pack_mod

PORTAL = "https://mods.factorio.com"
INIT_PUBLISH = f"{PORTAL}/api/v2/mods/init_publish"
INIT_UPLOAD = f"{PORTAL}/api/v2/mods/releases/init_upload"

# Portal license / category enums (see Mod details API).
# Categories: no-category, content, overhaul, tweaks, utilities, scenarios,
# mod-packs, localizations, internal.
DEFAULT_CATEGORY = "utilities"
LICENSE_MAP = {
    "mit": "default_mit",
    "MIT": "default_mit",
    "gplv3": "default_gnugplv3",
    "gpl-3.0": "default_gnugplv3",
    "apache-2.0": "default_apache2",
    "unlicense": "default_unlicense",
    "default": "default_mit",
}


def require_requests() -> None:
    if requests is None:
        raise SystemExit(
            "Missing dependency 'requests'. Install with: pip install requests"
        )


def api_key() -> str:
    key = os.environ.get("FACTORIO_API_KEY") or os.environ.get("MOD_UPLOAD_API_KEY")
    if not key:
        raise SystemExit(
            "Set FACTORIO_API_KEY (GitHub Actions secret or local env) before publishing."
        )
    return key.strip()


def portal_mod_full(mod_name: str) -> tuple[int, dict | None]:
    url = f"{PORTAL}/api/mods/{mod_name}/full"
    req = urllib.request.Request(url, headers={"User-Agent": "atmos_factorio_mods-publish"})
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        if exc.code == 404:
            return 404, None
        raise SystemExit(f"Portal lookup failed ({exc.code}) for {mod_name}: {body}")


def version_exists(payload: dict, version: str) -> bool:
    releases = payload.get("releases") or []
    return any(str(r.get("version")) == version for r in releases)


def read_description(mod_path: Path) -> str:
    readme = mod_path / "README.md"
    if readme.is_file():
        return readme.read_text(encoding="utf-8")
    info = load_info(mod_path)
    return str(info.get("description") or info.get("title") or info["name"])


def map_license(raw: str | None) -> str:
    if not raw:
        return "default_mit"
    mapped = LICENSE_MAP.get(raw) or LICENSE_MAP.get(str(raw).lower())
    return mapped or "default_mit"


def upload_zip(
    *,
    mod_name: str,
    zip_path: Path,
    first_publish: bool,
    description: str,
    license_id: str,
    source_url: str | None,
    category: str,
    dry_run: bool,
) -> None:
    init_url = INIT_PUBLISH if first_publish else INIT_UPLOAD
    action = "publish" if first_publish else "upload"

    if dry_run:
        print(
            f"[dry-run] would {action} {mod_name} from {zip_path} "
            f"(category={category}, license={license_id}, url={init_url})"
        )
        return

    require_requests()
    key = api_key()

    init = requests.post(
        init_url,
        data={"mod": mod_name},
        headers={"Authorization": f"Bearer {key}"},
        timeout=60,
    )
    if not init.ok:
        raise SystemExit(f"init_{action} failed ({init.status_code}): {init.text}")

    upload_url = init.json().get("upload_url")
    if not upload_url:
        raise SystemExit(f"init_{action} response missing upload_url: {init.text}")

    form: dict[str, str] = {}
    if first_publish:
        form["description"] = description
        form["category"] = category
        form["license"] = license_id
        if source_url:
            form["source_url"] = source_url

    with zip_path.open("rb") as handle:
        finish = requests.post(
            upload_url,
            files={"file": (zip_path.name, handle, "application/zip")},
            data=form,
            timeout=300,
        )

    if not finish.ok:
        raise SystemExit(f"finish upload failed ({finish.status_code}): {finish.text}")

    print(f"Portal {action} OK for {mod_name}: {finish.text}")


def publish_mod_dir(
    mod_path: Path,
    *,
    out_dir: Path,
    dry_run: bool,
    category: str,
    expected_version: str | None = None,
) -> None:
    info = load_info(mod_path)
    mod_name = str(info["name"])
    version = str(info["version"])

    if expected_version and expected_version != version:
        raise SystemExit(
            f"Tag/version mismatch for {mod_path.name}: "
            f"tag={expected_version} info.json={version}"
        )

    status, payload = portal_mod_full(mod_name)
    first_publish = status == 404
    if payload and version_exists(payload, version):
        print(f"Skip {mod_name} {version}: already on Mod Portal")
        return

    zip_path = pack_mod(mod_path, out_dir)
    source_url = info.get("homepage") or None
    upload_zip(
        mod_name=mod_name,
        zip_path=zip_path,
        first_publish=first_publish,
        description=read_description(mod_path),
        license_id=map_license(info.get("license")),
        source_url=source_url,
        category=category,
        dry_run=dry_run,
    )
    if first_publish:
        print(f"First publish: {mod_name} {version}")
    else:
        print(f"Updated release: {mod_name} {version}")


def resolve_mod_path(repo_root: Path, value: str) -> Path:
    path = Path(value)
    if not path.is_absolute():
        path = repo_root / path
    if not path.is_dir():
        raise SystemExit(f"Mod directory not found: {path}")
    if not (path / "info.json").is_file():
        raise SystemExit(f"Missing info.json in: {path}")
    return path


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "mod_dir",
        nargs="?",
        help="Mod folder (relative to repo root) or omit with --all",
    )
    parser.add_argument("--all", action="store_true", help="Publish every mod folder")
    parser.add_argument("--out", default="dist", help="Zip output directory")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Pack and resolve publish/update path without uploading",
    )
    parser.add_argument(
        "--category",
        default=DEFAULT_CATEGORY,
        help=f"Portal category for first publish (default: {DEFAULT_CATEGORY})",
    )
    parser.add_argument(
        "--expect-version",
        help="Require info.json version to match (used by tag workflows)",
    )
    parser.add_argument("--repo-root", default=str(REPO_ROOT))
    args = parser.parse_args(argv)

    repo_root = Path(args.repo_root).resolve()
    out_dir = Path(args.out)
    if not out_dir.is_absolute():
        out_dir = repo_root / out_dir

    if args.all:
        mods = iter_mod_dirs(repo_root)
        if not mods:
            raise SystemExit(f"No mod folders with info.json under {repo_root}")
        failures: list[str] = []
        for mod in mods:
            try:
                publish_mod_dir(
                    mod,
                    out_dir=out_dir,
                    dry_run=args.dry_run,
                    category=args.category,
                    expected_version=args.expect_version,
                )
            except SystemExit as exc:
                failures.append(f"{mod.name}: {exc}")
                print(f"ERROR {mod.name}: {exc}", file=sys.stderr)
            except Exception as exc:  # noqa: BLE001 - keep publishing remaining mods
                failures.append(f"{mod.name}: {exc}")
                print(f"ERROR {mod.name}: {exc}", file=sys.stderr)
        if failures:
            print("Publish finished with errors:", file=sys.stderr)
            for item in failures:
                print(f"  - {item}", file=sys.stderr)
            return 1
        return 0

    if not args.mod_dir:
        parser.error("Specify mod_dir or --all")

    mod_path = resolve_mod_path(repo_root, args.mod_dir)
    publish_mod_dir(
        mod_path,
        out_dir=out_dir,
        dry_run=args.dry_run,
        category=args.category,
        expected_version=args.expect_version,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
