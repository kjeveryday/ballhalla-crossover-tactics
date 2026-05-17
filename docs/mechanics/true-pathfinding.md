# True Pathfinding

## Summary

Replaced greedy axis-choice step-toward in `MovementSystem` and `EnemyAI` with BFS
path reconstruction. Allied ballers follow the pre-computed BFS route stored at move
initiation. Enemies run BFS from their current position each beat to navigate
around occupied cells.

## How it works

### Allied movement
1. `TargetOverlay.show_move_range()` calls `GridManager.mark_reachable_cells()` — BFS
   runs from the selected baller, storing `pf_root` backpointers on every reachable cell.
2. Player clicks a destination → `AbilitySystem.initiate_move()` calls
   `GridManager.get_path_to_cell(dest)` to reconstruct the full route, then
   `MovementSystem.set_path(baller, path)` stores the remaining steps.
3. Each beat `MovementSystem.continue_movement()` pops the next cell from the stored
   path. If no path is stored (e.g., programmatic initiation), falls back to greedy.

### Enemy movement
`EnemyAI._move_one_step_toward()` runs `mark_reachable_cells` from the enemy's
current position each beat (range = GRID_COLS + GRID_ROWS = 21, covers the full court),
then reconstructs path to target and takes step `path[1]`.

## D2 resolved
Multi-beat movement confirmed. One step per beat. `is_in_motion` pattern unchanged.

## Behaviors

| # | Behavior |
|---|----------|
| B1 | `MovementSystem.set_path(baller, path)` stores pre-computed route (origin stripped) |
| B2 | `continue_movement` consumes stored path one step per call; erases on arrival |
| B3 | Greedy axis-choice fallback retained when no path stored |
| B4 | `AbilitySystem.initiate_move` calls `set_path` before first `continue_movement` |
| B5 | `AbilitySystem.perform_cut` calls `set_path` before first `continue_movement` |
| B6 | `EnemyAI._move_one_step_toward` runs BFS each beat, takes `path[1]` step |
| B7 | Enemy function returns early (`path.size() < 2`) if already at target or unreachable |

## Files Changed

- `autoloads/MovementSystem.gd` — `_paths` dict, `set_path()`, path-aware `continue_movement`
- `autoloads/AbilitySystem.gd` — `set_path` call in `initiate_move` and `perform_cut`
- `autoloads/EnemyAI.gd` — `_move_one_step_toward` replaced with BFS step

## Notes

`_paths` entries for a baller are erased on arrival. Stale entries (e.g., baller
deactivated mid-move) are harmless — the key will be overwritten on the next
`set_path` call.

Enemy BFS re-runs `mark_reachable_cells` each beat, which clears allied pathfinding
markers. This is safe because allied paths are stored in `MovementSystem._paths`, not
in grid cell state.
