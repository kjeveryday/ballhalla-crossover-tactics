# Movement Range Highlight

## Summary

`TargetOverlay` hardcoded range=3 for move, cut, and preview highlights regardless
of baller position. Fixed to read `AbilitySystem.get_move_range(baller)` for all
three methods. `show_move_range` also switches from `get_cells_in_range` to
`mark_reachable_cells` so the BFS pf_distance/pf_root data is cached on cells for
path reconstruction when `true-pathfinding` is implemented.

## Effective ranges by position

| Position | Speed modifier | Move range |
|----------|---------------|------------|
| PG | +2 | 6 |
| SG | +2 | 6 |
| SF | 0  | 4 |
| PF | -2 | 2 |
| C  | -2 | 2 |

## Behaviors

| # | Behavior |
|---|----------|
| B1 | `show_move_range()` uses `AbilitySystem.get_move_range(baller)` — no hardcoded range |
| B2 | `show_move_range()` calls `GridManager.mark_reachable_cells()` to cache BFS data |
| B3 | `show_cut_range()` uses actual move range via `AbilitySystem.get_move_range(baller)` |
| B4 | `preview_move_range()` uses actual move range via `AbilitySystem.get_move_range(baller)` |
| B5 | Impassable cells (`passable == false`) are automatically excluded by BFS in `mark_reachable_cells` |

## Files Changed

- `scenes/battle/TargetOverlay.gd` — `show_move_range`, `show_cut_range`, `preview_move_range`

## Notes

`preview_move_range` (hover preview) intentionally keeps `get_cells_in_range` rather
than `mark_reachable_cells` — calling `mark_reachable_cells` on hover would wipe the
pf_distance state cached when the player commits to Move. Only `show_move_range` (the
commit path) writes pathfinding state.
