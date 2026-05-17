# Design Doc: occupant-tracking

## Summary

`GridCell.occupant` exists in `GridManager` but is never set or cleared by any system. As a
result, `mark_reachable_cells()` (which checks `cell.occupant == null` to flag valid destinations)
always treats every cell as empty. Ballers can legally move into occupied cells, and `TargetOverlay`
cannot filter occupied destinations. This silently corrupts all movement and targeting in Phase 2.

This mechanic fixes occupant tracking by making it a contract of three locations that mutate grid
position, without changing any visual or game-logic behavior.

---

## Behaviours to Implement

### B1 — place_on_grid() clears old cell and sets new cell

`Baller.place_on_grid(col, row)` is the canonical method for teleporting a baller to a grid
position (used at spawn, at `_ready()`, and by anything that needs instant placement).

Before updating `grid_col/grid_row`, clear the baller's current cell:
```gdscript
var old_cell := GridManager.get_cell(grid_col, grid_row)
if old_cell != null and old_cell.occupant == self:
    old_cell.occupant = null
```
Guard with `occupant == self` so we only clear a cell we actually own — not a cell that was
reassigned to another baller between calls.

After updating `grid_col = col` / `grid_row = row`, set the new cell:
```gdscript
var new_cell := GridManager.get_cell(col, row)
if new_cell != null:
    new_cell.occupant = self
```

Do NOT change the `position = GridManager.grid_to_world(col, row)` line — visual behaviour is
unchanged. (Step 17 will refactor visual vs. logical position separately.)

### B2 — MovementSystem updates occupants on each step

`MovementSystem.continue_movement()` directly assigns `baller.grid_col = next.x` and
`baller.grid_row = next.y` without calling `place_on_grid()` (it needs to skip the visual update
so BattleDemo can tween the position separately). It must also maintain occupants.

After computing `next` and confirming the cell exists, and **before** the existing
`baller.grid_col = next.x` assignment:
```gdscript
var old_cell := GridManager.get_cell(baller.grid_col, baller.grid_row)
if old_cell != null and old_cell.occupant == baller:
    old_cell.occupant = null
```

After `baller.grid_col = next.x` / `baller.grid_row = next.y`:
```gdscript
var new_cell := GridManager.get_cell(next.x, next.y)
if new_cell != null:
    new_cell.occupant = baller
```

No other logic in `continue_movement()` changes.

### B3 — EnemyAI updates occupants on each step

`EnemyAI._move_one_step_toward()` has the same pattern — direct `enemy.grid_col = next_col`
assignment without `place_on_grid()`. Apply the identical occupant-clear-then-set pattern around
those assignments, exactly as in B2.

### B4 — Baller clears its cell on deactivation

When `baller.is_active` is set to false, the baller should vacate its cell so pathfinding treats
it as empty. Add a setter on `is_active`:
```gdscript
var is_active: bool = true:
    set(value):
        is_active = value
        if not value:
            var cell := GridManager.get_cell(grid_col, grid_row)
            if cell != null and cell.occupant == self:
                cell.occupant = null
```

---

## What Does NOT Change

- `GridCell` struct — `occupant` field already exists, no schema change needed.
- `mark_reachable_cells()` — already filters `cell.occupant == null`; will now work correctly.
- `TargetOverlay.show_move_range()` — already reads `GridCell.occupant`; will now work correctly.
- All game logic, stamina, hype, shot resolution — untouched.
- Visual positions — `place_on_grid()` still sets `baller.position`.

---

## Files to Modify

| File | Change |
|------|--------|
| `entities/baller/Baller.gd` | B1: update `place_on_grid()`, B4: add setter on `is_active` |
| `autoloads/MovementSystem.gd` | B2: add occupant clear/set around grid_col/row assignment |
| `autoloads/EnemyAI.gd` | B3: add occupant clear/set around grid_col/row assignment |

---

## Test Cases

- **T1:** After `place_on_grid(3, 5)`, `GridManager.get_cell(3, 5).occupant == baller` is true.
- **T2:** After moving from `(3, 5)` to `(3, 6)`, `get_cell(3, 5).occupant == null` and `get_cell(3, 6).occupant == baller`.
- **T3:** `mark_reachable_cells()` does not flag an occupied cell as reachable.
- **T4:** Two ballers placed at different cells do not share occupancy.
- **T5:** Setting `is_active = false` clears the baller's cell occupant.
- **T6:** `place_on_grid()` called with the baller's current position (same col/row) is a no-op — occupant remains self.
