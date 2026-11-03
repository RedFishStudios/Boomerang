# Backup: manual recall "rise, then zoom" (before 2026-11-02)

Full copies of the scripts as they were before the manual recall was changed to the **ground approach**
(the charge keeps the boomerang on the ground; it then flies to the player at once, rising slowly while it speeds up
over about 60 studs). Saved as `.txt` and outside `src/`, so Rojo never syncs them into the game.

| File | Was |
|---|---|
| `Boomerang.luau.txt` | `src/Shared/Logics/WeaponLogics/Boomerang.luau` |
| `Dead.luau.txt` | `src/Shared/Logics/WeaponLogics/Dead.luau` |
| `GlobalConfig.luau.txt` | `src/Shared/Constants/GlobalConfig.luau` |

## Going back

- **Quickest:** set `GlobalConfig.ManualRecallGroundApproach = false`. The old behaviour is still in the code; every
  new piece is marked `GROUND APPROACH (2026-11-02)`.
- **Fully:** revert the commit that added the ground approach, or copy these files back over the live ones (only if
  nothing else has changed in them since; otherwise compare first).
