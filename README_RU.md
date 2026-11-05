# atmos_factorio_mods

Монорепозиторий модов для Factorio **2.1**.

| Мод | Папка |
| --- | --- |
| Atmos Shotgun Tiers | [atmos_shotgun_tiers](atmos_shotgun_tiers) |
| Atmos Enemy Range Visualizer | [atmos_enemy_range_visualizer](atmos_enemy_range_visualizer) |

Имя мода в игре / на портале задаётся в `info.json` каждого мода (после публикации не переименовывать).

English overview: [README.md](README.md)

## Рекомендуемый компаньон

Для кругов дальности своего оружия/техники — **[Gun Range Visualizer](https://mods.factorio.com/mod/gun-range-visualizer)** (рекомендуется модом Atmos Enemy Range Visualizer).

## Упаковка

```powershell
.\scripts\pack-mod.ps1 -ModDir atmos_enemy_range_visualizer
# или
py -3 scripts/pack-mod.py atmos_shotgun_tiers
```

Zip-архивы пишутся в `dist/{name}_{version}.zip`.

## Публикация / обновление (Mod Portal)

Нужен GitHub Actions secret `FACTORIO_API_KEY`.

- **Вручную:** Actions → *Publish Factorio mods* → мод или `all`
- **Тег:** `git tag atmos_shotgun_tiers/2.1.1 && git push origin atmos_shotgun_tiers/2.1.1`
- **Локально:** `py -3 scripts/publish-mod.py atmos_shotgun_tiers` (нужны `FACTORIO_API_KEY` и `pip install requests`)
