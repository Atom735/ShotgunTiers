---
name: factorio-mod-packaging
description: >-
  Build Factorio Mod Portal release zip packages from mod folders in this
  monorepo. Use when packaging, publishing, updating, releasing, or uploading a
  mod; when the user asks for a zip, portal package, or pack-mod script.
---

# Factorio mod packaging

## Portal zip rules

- Zip file name: `{info.name}_{info.version}.zip` (example: `Atmos-Shotgun-Tiers_2.1.0.zip`)
- Inside the zip: one root folder `{info.name}_{info.version}/` containing mod files (`info.json` at that folder root)
- Prefer including: Lua sources, `info.json`, `changelog.txt`, `locale/`, `migrations/`, graphics, `thumbnail.png`, `LICENSE`
- Exclude: `.git*`, `.cursor/`, `dist/`, other zips, `README*.md`, `changelog_RU.txt`, editor junk

Official structure: https://lua-api.factorio.com/latest/auxiliary/mod-structure.html

## Scripts

From repo root:

```powershell
# Pack one mod folder
.\scripts\pack-mod.ps1 -ModDir atmos_shotgun_tiers

# Pack all top-level mod folders that contain info.json
.\scripts\pack-mod.ps1 -All

# Custom output directory (default: dist/)
.\scripts\pack-mod.ps1 -ModDir atmos_shotgun_tiers -OutDir dist
```

Cross-platform Python (3.8+), same flags. On Windows prefer `py -3` if `python` points to an old install:

```bash
py -3 scripts/pack-mod.py atmos_shotgun_tiers
py -3 scripts/pack_mod.py --all
py -3 scripts/pack-mod.py atmos_shotgun_tiers --out dist
```

Implementation module: `scripts/pack_mod.py` (`pack-mod.py` is a thin CLI alias).


Output path: `dist/{name}_{version}.zip`.

## Pre-pack checklist

- [ ] `info.json` version bumped
- [ ] `changelog.txt` has matching `Version:` section (strict format)
- [ ] EN/RU locales updated together
- [ ] `factorio_version` is `"2.1"`
- [ ] No secrets in the mod folder
- [ ] Optional: `thumbnail.png` present (144x144 ideal)

## Publish / update (Mod Portal)

Requires secret `FACTORIO_API_KEY` (scopes: `ModPortal: Upload Mods`; also `ModPortal: Publish Mods` for first publish).

```bash
pip install requests
# Pack + publish/update one mod (skips if version already exists)
py -3 scripts/publish-mod.py atmos_shotgun_tiers
# All mods
py -3 scripts/publish-mod.py --all
# Pack/resolve only
py -3 scripts/publish-mod.py atmos_shotgun_tiers --dry-run
```

GitHub Actions: `.github/workflows/publish-mods.yml`

- Manual: Actions → **Publish Factorio mods** → choose mod/`all`, optional dry-run
- Tag push: `git tag atmos_shotgun_tiers/2.1.1 && git push origin atmos_shotgun_tiers/2.1.1`
  (folder/version must match `info.json`)

Script auto-chooses first publish (`init_publish`) vs update (`init_upload`).

## After pack

1. Smoke-test: unzip and confirm `info.json` path is `{name}_{version}/info.json`
2. Publish via workflow/script **or** upload manually on https://mods.factorio.com
3. For updates: same mod `name`, higher `version`; portal rejects duplicate versions

## Agent instructions

- Prefer running the existing scripts; do not hand-roll ad-hoc zips unless scripts fail
- On Windows prefer `pack-mod.ps1` / `py -3` for Python scripts
- Report the produced zip path and `name`/`version` from `info.json`
- Do not upload to the portal unless the user explicitly asks and `FACTORIO_API_KEY` is available
