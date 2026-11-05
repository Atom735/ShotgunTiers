# Factorio 2.1 reference notes

## Recipe categories migration

| 2.0 / older | 2.1 |
| --- | --- |
| `category = "smelting"` | `categories = { "smelting" }` |
| `category` + `additional_categories` | single `categories` array |

Empty `categories` is invalid. Base `"crafting"` cannot include fluid ingredients/products.

## Dependency string shapes

```
"base >= 2.1.0"
"? quality"
"! conflicting-mod"
"~ load-order-neutral-mod"
"(?) hidden-optional-mod"
"+ recommended-mod"
```

## Settings types

Common: `bool-setting`, `int-setting`, `double-setting`, `string-setting`.

`setting_type`: `startup` | `runtime-global` | `runtime-per-user`.

Read in data stage: `settings.startup["my-setting"].value`.

## Locale file tips

- UTF-8 without BOM
- `=` separates key and value
- `__1__`, `__2__` for parameters
- Mod title/description overrides: `[mod-name]` / `[mod-description]` with internal mod name as key

## Migrations

Place Lua or JSON migrations under `migrations/`. Use when renaming prototypes or restructuring `storage` between versions so existing saves load cleanly.

## Portal vs repo docs

| File | Game / portal | GitHub repo |
| --- | --- | --- |
| `info.json` description | Yes (in-game browser) | Yes |
| `changelog.txt` | Yes (strict format in-game) | Yes |
| `changelog_RU.txt` | No | Yes (RU readers) |
| `README.md` | No | Yes |
| `README_RU.md` | No | Yes |
| `thumbnail.png` | Yes | Yes |
| `locale/*` | Yes | Yes |

## Useful links

- https://lua-api.factorio.com/latest/
- https://lua-api.factorio.com/latest/auxiliary/mod-structure.html
- https://lua-api.factorio.com/latest/auxiliary/changelog-format.html
- https://lua-api.factorio.com/latest/auxiliary/data-lifecycle.html
- https://mods.factorio.com/
