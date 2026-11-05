# atmos_factorio_mods

Monorepo for Factorio **2.1** mods.

| Mod | Folder |
| --- | --- |
| Atmos Shotgun Tiers | [atmos_shotgun_tiers](atmos_shotgun_tiers) |
| Atmos Enemy Range Visualizer | [atmos_enemy_range_visualizer](atmos_enemy_range_visualizer) |

The in-game / portal mod id stays as in each mod's `info.json` (do not rename after publish).

Russian overview: [README_RU.md](README_RU.md)

## Recommended companion

For personal gun/vehicle range circles, use **[Gun Range Visualizer](https://mods.factorio.com/mod/gun-range-visualizer)** (recommended by Atmos Enemy Range Visualizer).

## Packaging

```powershell
.\scripts\pack-mod.ps1 -ModDir atmos_enemy_range_visualizer
# or
py -3 scripts/pack-mod.py atmos_shotgun_tiers
```

Zips are written to `dist/{name}_{version}.zip`.

## Publish / update (Mod Portal)

Uses GitHub Actions secret `FACTORIO_API_KEY`.

- **Manual:** Actions → *Publish Factorio mods* → pick mod or `all`
- **Tag:** `git tag atmos_shotgun_tiers/2.1.1 && git push origin atmos_shotgun_tiers/2.1.1`
- **Local:** `py -3 scripts/publish-mod.py atmos_shotgun_tiers` (needs `FACTORIO_API_KEY` + `pip install requests`)
