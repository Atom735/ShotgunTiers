# Atmos Auto Fire

Factorio 2.1 mod that automatically fires the shotgun in the player's hands.

The character itself pulls the trigger: the mod sets the character's shooting state at the chosen target, so spread, range, cooldown, ammo use, and research bonuses are exactly those of the held gun.

## Behavior

- Active while the selected weapon name contains `shotgun` and the shortcut is on.
- A target is picked every 5 ticks; the trigger is held every tick while that target stays valid and in range.
- While a target is held, it overrides manual aiming. With no target, manual shooting works as usual.

## Allow / forbid lists

Allow rows are checked from top to bottom. Each row can be:

- ★ All enemies
- An entity type (spawners, combat robots, units, worm/turret type, spider units, segmented units)
- A specific game entity (choose-elem picker)

Each allow row has a range slider and an `m` / `%` switch:

- `m` — absolute meters
- `%` — percent of the held weapon's firing range

Forbid entries are never selected as targets and also block the line of fire.

Default allow order:

1. All at 10% range
2. Spawners
3. Combat robots
4. Worms behemoth → small
5. Spitters behemoth → small
6. Biters behemoth → small
7. All at 100% range

Default forbid: gun turret, laser turret, flamethrower turret.

Avoid-own-buildings line-of-fire check is on by default: a target is skipped while the shot cone toward it crosses an own or allied building (or a forbidden entity).

The "Show debug overlay" checkbox draws ranges, candidates with their allow row, shot cones, and blocking buildings.

## Controls

- Top bar: shotgun button opens or closes the settings window.
- Shortcut bar: toggles auto-fire. Default key `CONTROL + ALT + G`.

## License

MIT
