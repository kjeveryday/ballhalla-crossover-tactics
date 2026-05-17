# Spec: Path Preview

## Summary

When the player is in Move targeting mode (`Mode.CELLS`), hovering the mouse
over a reachable destination cell displays the BFS path from the baller's
current position to that cell as a chain of small filled white circles, one per
step cell, with a distinct outlined ring drawn on top of the final destination
cell. The preview is cleared whenever the cursor leaves the valid range or moves
off-grid. All hover tracking, path storage, and drawing are implemented
exclusively inside `TargetOverlay.gd`; no other file is modified. Mouse motion
events are never consumed, so click-through behavior and other node interactions
are unaffected. The preview does not appear in any mode other than `Mode.CELLS`.

---

## Behaviors (B1–B7)

**B1 — Hover over reachable cell draws step dots**
While `_mode == Mode.CELLS`, each `InputEventMouseMotion` event must:
1. Convert `get_local_mouse_position()` to a grid coordinate via
   `GridManager.world_to_grid()`.
2. If the resulting `Vector2i` is contained in `_highlight_cells`, call
   `GridManager.get_path_to_cell(col, row)` and assign the returned
   `Array[GridManager.GridCell]` to `_hovered_path`.
3. Call `queue_redraw()`.
After `queue_redraw()` settles, `_draw()` must render a filled circle at every
step cell's world-center position (see Drawing Constants), skipping index 0.

**B2 — Hover over out-of-range or off-grid cell clears preview**
While `_mode == Mode.CELLS`, if the mouse-motion grid coordinate is NOT in
`_highlight_cells` (including the case where `world_to_grid()` returns
`Vector2i(-1, -1)`), `_hovered_path` must be set to `[]` and `queue_redraw()`
called. After redraw no path dots or destination ring appear.

**B3 — Origin cell (index 0) is not drawn**
`_draw()` iterates `_hovered_path` starting at index 1. The cell at index 0 is
the baller's current cell and must never have a step dot drawn on it, even when
`_hovered_path` has length 1 (i.e., the hovered cell equals the baller's
current cell — see Edge Cases).

**B4 — Destination cell receives a distinct ring**
After the step-dot pass, `_draw()` performs a second pass that draws one arc
(outline only) at the world-center of `_hovered_path.back()`, using the
destination-ring constants (see Drawing Constants). This ring is drawn on top of
the step dot for the same cell (if the path has length > 1) or produces no
visible output when `_hovered_path` is empty.

**B5 — Mouse motion does not consume input**
The `InputEventMouseMotion` branch in `_unhandled_input` must NOT call
`get_viewport().set_input_as_handled()`. Other event types (left-click, ESC,
RMB) are unaffected by this requirement and continue to behave as currently
implemented.

**B6 — `clear()` erases `_hovered_path` and redraws**
Calling `clear()` must assign `_hovered_path = []` in addition to its existing
behavior (setting `_mode = Mode.NONE`, clearing `_highlight_cells` and
`_highlight_ballers`, disabling unhandled input, calling `queue_redraw()`).
After `clear()` returns no path dots or ring are visible.

**B7 — Path preview is absent in all non-CELLS modes**
`_draw()` must not render any step dots or destination rings when
`_mode` is `Mode.NONE`, `Mode.CUT_CELLS`, `Mode.BALLERS`,
`Mode.PREVIEW_ENEMIES`, or `Mode.PREVIEW_CELLS`. The `_hovered_path`-based
draw code must be guarded by an explicit `_mode == Mode.CELLS` check (or live
inside the existing `if _mode == Mode.CELLS:` branch).

---

## Files Changed

### `scenes/battle/TargetOverlay.gd` (only file modified)

#### New state variable

| Variable | Type | Initial value | Purpose |
|---|---|---|---|
| `_hovered_path` | `Array` | `[]` | Stores the ordered list of `GridManager.GridCell` objects returned by `get_path_to_cell()` for the currently hovered reachable cell. Cleared when cursor leaves range or `clear()` is called. |

The variable is declared alongside the other private state variables near the
top of the file (after `_highlight_ballers`).

#### New drawing constants

| Constant | Type | Value |
|---|---|---|
| `C_PATH_DOT` | `Color` | `Color(1.0, 1.0, 1.0, 0.55)` |
| `C_PATH_RING` | `Color` | `Color(1.0, 1.0, 1.0, 0.80)` |

Declared alongside the existing `C_MOVE_FILL`, `C_MOVE_EDGE`, etc. constants.

#### Modified function: `clear()`

Add `_hovered_path = []` before or after the existing clear logic. The final
`queue_redraw()` call must remain the last statement.

#### Modified function: `_draw()`

Inside the existing `if _mode == Mode.CELLS:` block, after the loop that draws
`C_MOVE_FILL` and `C_MOVE_EDGE` rects, append:

1. **Step-dot pass** — iterate `_hovered_path` from index 1 to the end.
   For each `GridManager.GridCell` element, compute the world-center via
   `GridManager.grid_to_world(cell.col, cell.row)` and call:
   ```
   draw_circle(world_center, cs * 0.14, C_PATH_DOT)
   ```

2. **Destination-ring pass** — if `_hovered_path` is not empty, compute
   the world-center of `_hovered_path.back()` and call:
   ```
   draw_arc(world_center, cs * 0.22, 0.0, TAU, 32, C_PATH_RING, 2.0)
   ```

The step-dot pass must execute before the destination-ring pass so the ring
renders on top.

#### Modified function: `_unhandled_input(event: InputEvent)`

Inside the existing block that handles `InputEventMouseMotion` (to be added —
this branch does not yet exist), when `_mode == Mode.CELLS`:

```
if event is InputEventMouseMotion:
    var local_pos: Vector2 = get_local_mouse_position()
    var grid_pos: Vector2i = GridManager.world_to_grid(local_pos)
    if grid_pos != Vector2i(-1, -1) and _highlight_cells.has(grid_pos):
        _hovered_path = GridManager.get_path_to_cell(grid_pos.x, grid_pos.y)
    else:
        _hovered_path = []
    queue_redraw()
    # DO NOT call get_viewport().set_input_as_handled()
    return
```

This branch must be placed before the left-click branch so motion events are
handled without falling through to click logic.

---

## All New State Variables

| Variable | GDScript type | Declaration location | Default |
|---|---|---|---|
| `_hovered_path` | `Array` | Top of file, after `_highlight_ballers` | `[]` |

No new export variables. No changes to existing variable types.

---

## Drawing Constants (exact values from design doc)

| Constant name | Color RGBA | Radius (expressed in `CELL_SIZE` units) | Draw call | Extra params |
|---|---|---|---|---|
| `C_PATH_DOT` | `Color(1.0, 1.0, 1.0, 0.55)` | `CELL_SIZE * 0.14` | `draw_circle` | — |
| `C_PATH_RING` | `Color(1.0, 1.0, 1.0, 0.80)` | `CELL_SIZE * 0.22` | `draw_arc` | `angle_from=0.0`, `angle_to=TAU`, `point_count=32`, `width=2.0` |

Both are drawn on top of the blue reachable-cell fill (`C_MOVE_FILL` /
`C_MOVE_EDGE` rects) and below the cell edge outlines drawn by
`C_MOVE_EDGE`. Rendering order within `_draw()`:
1. `C_MOVE_FILL` rects (existing)
2. `C_MOVE_EDGE` rects (existing)
3. `C_PATH_DOT` circles (new — step dots, indices 1..N)
4. `C_PATH_RING` arc (new — destination ring, last cell)

---

## Edge Cases

**EC1 — Hovered cell is the baller's current cell (path length 1, index 0 only)**
`get_path_to_cell()` returns an array whose sole element is the baller's origin
cell. Because `_draw()` skips index 0, no step dot is drawn. The destination-
ring pass reads `_hovered_path.back()` which is the origin cell itself and
draws the ring there. This is the only visible output: a single ring on the
baller's own cell. A test must assert that `draw_circle` is NOT called (no step
dot) and `draw_arc` IS called with the origin cell's world-center.

**EC2 — `get_path_to_cell()` returns an empty array**
This should not occur for a cell that is in `_highlight_cells` (BFS guarantees
a path exists for every reachable cell), but if it does:
- The step-dot loop iterates zero times — no dots drawn.
- `_hovered_path.is_empty()` is true — the destination-ring guard prevents
  `draw_arc` from being called.
- No crash must occur. `_hovered_path` remains `[]`.

**EC3 — Mode switches to a non-CELLS mode while cursor is over a previously
hovered cell**
If `show_cut_range()`, `show_ally_targets()`, `preview_move_range()`,
`preview_trash_range()`, `preview_screen_target()`, or `clear()` is called
while `_hovered_path` is non-empty:
- `clear()` explicitly zeroes `_hovered_path`.
- The other `show_*` / `preview_*` functions do not clear `_hovered_path`
  directly, but because they set `_mode` to a value other than `Mode.CELLS`,
  `_draw()` will not enter the `Mode.CELLS` branch and the stale path is never
  rendered.
- The stale `_hovered_path` is harmless until the next `show_move_range()` call
  resets context. A test for B7 must confirm no path dots appear after a mode
  switch even if `_hovered_path` was previously populated.

**EC4 — `InputEventMouseMotion` fires before `show_move_range()` has been called
(mode is `Mode.NONE`)**
The existing early-return `if _mode == Mode.NONE: return` at the top of
`_unhandled_input` already guards against this. Additionally,
`set_process_unhandled_input(false)` in `_ready()` prevents any input from
reaching `_unhandled_input` until a `show_*` call enables it. No new guard
needed; this is documented for test completeness.

---

## Non-Goals (explicitly out of scope)

1. **Cut mode path preview** — `Mode.CUT_CELLS` uses `get_cells_in_range()`
   instead of `mark_reachable_cells()`, so `pf_root` backpointers are not
   populated. Wiring `mark_reachable_cells()` into `show_cut_range()` is
   required first and is a separate mechanic. No path dots or rings appear in
   `Mode.CUT_CELLS`.

2. **Animated path drawing** — dots and rings are drawn statically on every
   `_draw()` call. No tweening, sequencing, or frame-by-frame animation is
   implemented.

3. **Arrow or directional indicators** — only filled circles (step dots) and an
   arc (destination ring) are drawn. No arrows, chevrons, or line segments
   connecting steps.

4. **Path dot on the origin cell** — index 0 is always skipped. There is no
   option or configuration to show a dot on the baller's starting cell.

5. **Color theming or per-baller color variation** — `C_PATH_DOT` and
   `C_PATH_RING` are constants. They do not vary by baller, team, or ability.

6. **Preview modes path preview** — `Mode.PREVIEW_CELLS` and
   `Mode.PREVIEW_ENEMIES` do not receive path preview drawing.

7. **Pass / leadership target path preview** — `Mode.BALLERS` does not receive
   path preview drawing.

8. **BattleDemo changes** — the design doc explicitly states `BattleDemo` needs
   no changes. This spec enforces that constraint.

9. **`get_path_to_cell()` implementation** — this spec assumes
   `GridManager.get_path_to_cell(col: int, row: int) -> Array` already exists
   and returns an ordered `Array` of `GridManager.GridCell` from the origin to
   the destination using the `pf_root` backpointers set by
   `mark_reachable_cells()`. Implementing or modifying `get_path_to_cell()` is
   out of scope.
