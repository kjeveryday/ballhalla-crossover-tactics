# Grid Cell Types

## Summary

Extended `GridCell` with `passable` and `movement_cost` fields, and created
`GridCellConfig` so courts can override individual cells via .tres resources
without touching code.

## Decisions

- **Passability is static** — set at court load, never changed at runtime by gameplay.
  All 108 cells in the 9×12 grid default to `passable = true`. Future courts can
  mark specific cells impassable via `GridCellConfig` .tres overrides.
- **Screens are soft fields, not hard blocks** — `movement_cost` is the mechanism.
  When a screen is active, adjacent cells get elevated cost. BFS will weight paths
  accordingly in `true-pathfinding`. The `movement_cost` field exists here as
  infrastructure; it is not yet read by any pathfinding system.

## Behaviors

| # | Behavior |
|---|----------|
| B1 | `GridCell.passable` defaults to `true` for all cells |
| B2 | `GridCell.movement_cost` defaults to `1` |
| B3 | `mark_reachable_cells()` skips neighbors where `passable == false` |
| B4 | `get_cells_in_range()` skips neighbors where `passable == false` |
| B5 | `GridManager.apply_cell_config(config)` applies a `GridCellConfig` override to a cell |
| B6 | `GridCellConfig` is an exported Resource with `col`, `row`, `passable`, `movement_cost` |

## Files Changed

- `autoloads/GridManager.gd` — replaced `is_out_of_bounds` with `passable` + `movement_cost` on `GridCell`; added `passable` guard in BFS loops; added `apply_cell_config()`
- `resources/GridCellConfig.gd` — new Resource class for .tres court overrides

## Notes

`is_out_of_bounds: bool` was declared but never set or read by any system. Removed.
The `movement_cost` field will be consumed by the weighted BFS in `true-pathfinding`.
Screen gravity field implementation (setting adjacent cells' `movement_cost` on screen
perform and clearing on screen recovery) belongs to the screen mechanic rework, not here.
