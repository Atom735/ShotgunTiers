# Atmos Auto Heal

Factorio **2.1** mod that automatically eats fish, healing capsules, or any other self-healing item from your inventory when your health drops below a threshold.

## Features

- Detects every capsule with a self-heal effect at runtime (vanilla fish and modded items)
- Per-player priority list: reorder items and disable the ones you want to keep
- Toggle via shortcut bar or **Ctrl+Shift+H**
- Priority panel: **Ctrl+Shift+J**
- Respects each item's use cooldown
- Optional "avoid wasting heals" mode: prefers items that fit the missing health

## Settings (per player)

- Heal below health (%), default 70
- Avoid wasting heals, default on

## Compatibility

Incompatible with **Auto Fish and Heal** (`auto-fish`). Both mods do the same job, and `auto-fish` 1.1.0 crashes on Factorio 2.x (`game.active_mods` was moved to `script.active_mods`).

## License

MIT
