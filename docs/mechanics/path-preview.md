# Path Preview

## Summary

While in Move targeting mode (`TARGET_MOVE`), hovering a destination cell draws the
computed BFS path as a chain of small filled circles on each step cell. Implemented
entirely inside `TargetOverlay` — `BattleDemo` needs no changes.

## How it works

`show_move_range()` already calls `GridManager.mark_reachable_cells()`, which writes
`pf_root` backpointers on every reachable cell. `get_path_to_cell()` is a simple
backpointer walk that reads those markers without re-running BFS.

On every `InputEventMouseMotion` while in `Mode.CELLS`:
1. Convert mouse position to grid coordinates with `GridManager.world_to_grid()`.
2. If the hovered cell is in `_highlight_cells`, call `GridManager.get_path_to_cell(col, row)`
   and store the result as `_hovered_path` (Array of `GridManager.GridCell`).
3. If the hovered cell is out-of-range or off-grid, clear `_hovered_path`.
4. Call `queue_redraw()`.

`_draw()` iterates `_hovered_path` (skip index 0 — that's the baller's current cell)
and draws a small filled circle at each step's world center. A second pass draws a
dimmer, slightly larger ring on the final destination cell.

Mouse motion events are **not consumed** (`set_input_as_handled()` is NOT called) so
hover detection never blocks click-through to other nodes.

Path preview is scoped to `Mode.CELLS` (regular Move) only. `Mode.CUT_CELLS` uses
`get_cells_in_range()` instead of `mark_reachable_cells()`, so `pf_root` backpointers
are not populated — previewing cut paths requires wiring `mark_reachable_cells` into
`show_cut_range()` first, which is out of scope here.

## Behaviors

| # | Behavior |
|---|----------|
| B1 | Hovering a reachable cell in Move mode draws the BFS path as step dots |
| B2 | Hovering an out-of-range or off-grid cell clears the path preview |
| B3 | Origin cell (index 0) is not drawn — baller is already there |
| B4 | Destination cell gets a distinct ring on top of its step dot |
| B5 | Mouse motion does not consume input — no interaction side effects |
| B6 | `clear()` erases `_hovered_path` and redraws |
| B7 | Path preview does not appear in `Mode.CUT_CELLS`, `Mode.BALLERS`, or preview modes |

## Files Changed

- `scenes/battle/TargetOverlay.gd` — `_hovered_path`, motion handling in
  `_unhandled_input`, path draw pass in `_draw()`

## Visual spec

- Step dots: `Color(1.0, 1.0, 1.0, 0.55)`, radius = `CELL_SIZE * 0.14`
- Destination ring: `Color(1.0, 1.0, 1.0, 0.80)`, radius = `CELL_SIZE * 0.22`,
  drawn as arc (outline only, width 2.0)
- Both drawn on top of the blue reachable-cell fill, below the edge outline

## Notes

`get_path_to_cell()` is O(path_length) — safe to call on every mouse motion event.
The BFS cache from `mark_reachable_cells()` is valid for the entire duration of
`TARGET_MOVE` state (nothing re-runs BFS until the next `show_move_range()` call or
an enemy move beat). Stale cache is impossible during targeting because BeatManager
does not advance beats while the player is in targeting state.
