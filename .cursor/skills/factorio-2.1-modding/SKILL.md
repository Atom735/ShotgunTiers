---
name: factorio-2.1-modding
description: >-
  Develop and maintain Factorio 2.1 mods in this monorepo: prototypes, data
  lifecycle, settings, locales EN/RU, changelog format, and 2.1 API migrations.
  Use when creating or editing Factorio mods, info.json, data.lua, settings.lua,
  control.lua, locale cfg files, or porting mods to Factorio 2.1.
---

# Factorio 2.1 modding

## Repo conventions

- Code/docs default language: **English**
- Russian mirrors: `README_RU.md`, `changelog_RU.txt`
- Locales: `locale/en/` + `locale/ru/` with matching keys
- Target `factorio_version`: `"2.1"`; depend on `"base >= 2.1.0"` unless a mod intentionally differs

Official refs:

- [Mod structure](https://lua-api.factorio.com/latest/auxiliary/mod-structure.html)
- [Changelog format](https://lua-api.factorio.com/latest/auxiliary/changelog-format.html)
- [Data lifecycle](https://lua-api.factorio.com/latest/auxiliary/data-lifecycle.html)
- [Prototype docs](https://lua-api.factorio.com/latest/)

## Load stages

| Stage | Files | Use for |
| --- | --- | --- |
| Settings | `settings.lua`, `settings-updates.lua`, `settings-final-fixes.lua` | Startup/runtime/map settings prototypes |
| Data | `data.lua`, `data-updates.lua`, `data-final-fixes.lua` | Items, recipes, entities, tech |
| Runtime | `control.lua` | Events, scripting (`script`, `game`, `storage`) |

Prefer `data-final-fixes.lua` when patching other mods' prototypes.

## info.json checklist

```json
{
  "name": "My-Mod-Name",
  "version": "1.0.0",
  "title": "My Mod Title",
  "author": "Atom735",
  "factorio_version": "2.1",
  "description": "Short EN description for in-game browser.",
  "dependencies": ["base >= 2.1.0", "? quality"],
  "homepage": "https://github.com/Atom735/atmos_factorio_mods/tree/main/<folder>"
}
```

- Portal `name`: alphanumeric, `-`, `_` only; do not rename after publish if it breaks the page/saves
- Optional Space Age feature flags only when needed (`quality_required`, `space_travel_required`, etc.)
- Optional dep: `"?"`; incompatible: `"!"`; hard: no prefix

## Factorio 2.1 gotchas

1. **Recipes use `categories` (array)**, not `category` / `additional_categories`:
   ```lua
   categories = { "crafting" }
   ```
2. **Typed ingredients/results**:
   ```lua
   ingredients = { { type = "item", name = "iron-plate", amount = 1 } },
   results = { { type = "item", name = "iron-gear-wheel", amount = 1 } },
   ```
3. Guard missing `data.raw` types: `for _, item in pairs(data.raw[type] or {}) do`
4. Clone prototypes with `table.deepcopy` before mutate; register via `data:extend({ ... })`
5. Runtime: prefer `storage` (not legacy `global`); check API when touching entity flags / fluid APIs

## Locales

```
locale/en/config.cfg
locale/ru/config.cfg
```

Typical sections: `[mod-name]`, `[mod-description]`, `[item-name]`, `[entity-name]`, `[recipe-name]`, `[modifier-description]`, `[string-mod-setting]`, `[string-mod-setting-description]`.

Keep EN/RU key sets identical for player-facing strings.

## Changelog (`changelog.txt`)

Strict in-game format:

```
---------------------------------------------------------------------------------------------------
Version: 1.2.3
Date: 2026-11-05
  Features:
    - Added something.
  Bugfixes:
    - Fixed something.
```

Rules: exactly 99 dashes; no tabs; no trailing spaces; categories indented 2 spaces and end with `:`; entries `    - ` (4 spaces, dash, space). Recognized categories include Features, Changes, Bugfixes, Compatibility, Locale, Balancing, Gui, Modding, Scripting.

Mirror notable notes in `changelog_RU.txt` when present.

## New mod scaffold

```
<mod_folder>/
  info.json
  data.lua                 # and/or data-updates / data-final-fixes
  settings.lua             # if needed
  control.lua              # if runtime needed
  changelog.txt
  changelog_RU.txt         # optional RU mirror
  README.md
  README_RU.md
  LICENSE
  thumbnail.png            # 144x144 recommended
  locale/en/config.cfg
  locale/ru/config.cfg
  migrations/              # if upgrading saves
```

## Workflow

1. Confirm Factorio 2.1 API for touched prototypes
2. Edit data/settings/control as needed
3. Update EN + RU locales together
4. Append `changelog.txt` (+ `_RU` if used) for the new version
5. Bump `info.json` `version`
6. Pack with `factorio-mod-packaging` before portal upload

## Additional resources

- Packaging and portal zip rules: see skill `factorio-mod-packaging`
- Deeper 2.1 migration notes: [reference.md](reference.md)
