# Atmos Enemy Range Visualizer

Factorio **2.1** mod that draws attack-range circles around **enemy** worms, turrets, and artillery — similar in spirit to [Gun Range Visualizer](https://mods.factorio.com/mod/gun-range-visualizer), but for hostile defenses.

## Features

- Toggle via shortcut bar or **Ctrl+Shift+R**
- Settings panel: **Ctrl+Shift+E** (enable, style, category filters)
- Styles: **filled**, **outline**, **filled + outline**
- Separate colors for worms / ammo / electric / fluid / artillery (Mod settings)
- Multiplayer-friendly: each player sees only their own overlays

## Recommended companion

Install **[Gun Range Visualizer](https://mods.factorio.com/mod/gun-range-visualizer)** for your own gun/vehicle range. This mod lists it as a recommended dependency (`+ gun-range-visualizer`).

## Covered enemy types

| Category | Entity types |
| --- | --- |
| Worms | `turret` (small/medium/big/behemoth worms, modded worms) |
| Ammo turrets | `ammo-turret` |
| Electric turrets | `electric-turret` |
| Fluid turrets | `fluid-turret` |
| Artillery | `artillery-turret` |

Only entities on forces that are **enemies** of the player are shown.

## License

MIT
