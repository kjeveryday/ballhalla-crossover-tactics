# Code Review: path-preview

**Reviewer:** ballhalla-reviewer
**Date:** 2026-05-17
**Spec:** `specs/path-preview.md`
**File reviewed:** `scenes/battle/TargetOverlay.gd`

---

## Verdict: PASS (0 Critical)

All spec requirements are satisfied. Two Minor findings noted below. No blockers to advancing to Stage 5.

---

## Spec Compliance Checklist

| ID | Requirement | Result |
|----|-------------|--------|
| B1 | MouseMotion in CELLS mode → convert pos, check `_highlight_cells`, call `get_path_to_cell`, assign `_hovered_path`, `queue_redraw()` | PASS |
| B2 | Out-of-range or off-grid → `_hovered_path = []`, `queue_redraw()` | PASS |
| B3 | `_draw()` iterates from index 1, never draws dot at index 0 | PASS |
| B4 | Destination ring uses `_hovered_path.back()` guarded by `is_empty()` | PASS |
| B5 | MouseMotion branch does NOT call `set_input_as_handled()` | PASS |
| B6 | `clear()` assigns `_hovered_path = []` | PASS |
| B7 | Path drawing code lives entirely inside `if _mode == Mode.CELLS:` | PASS |
| EC1 | Path length 1: `range(1,1)` = 0 dot iterations; ring draws on origin cell | PASS |
| EC2 | Empty path: loop runs 0 times, `is_empty()` guard blocks `draw_arc`; no crash | PASS |
| EC3 | Stale path after mode switch: `_draw()` never enters CELLS branch; stale data harmless | PASS (spec-permitted) |
| EC4 | Motion before `show_move_range()`: guarded by `_mode == Mode.NONE` early-return and `set_process_unhandled_input(false)` in `_ready()` | PASS |

---

## Findings

### Minor — M1: `_hovered_path` not typed as `Array[GridManager.GridCell]`

**Location:** Line 15
```gdscript
var _hovered_path: Array = []      # Array of GridCell — BFS path to hovered cell
```

**Issue:** The variable is declared as the untyped `Array` rather than `Array[GridManager.GridCell]`. GDScript 4 supports typed arrays, and `CLAUDE.md` mandates strict typing on every variable. The comment documents the element type but the compiler does not enforce it.

The per-element annotation in `_draw()` (`var step: GridManager.GridCell = _hovered_path[i]`) provides runtime enforcement but not static enforcement.

**Risk:** Low — a wrong-typed element would produce a runtime error rather than a silent bug. However it is a style violation.

**Fix:**
```gdscript
var _hovered_path: Array[GridManager.GridCell] = []
```
Note: if `GridManager.GridCell` is an inner class, confirm GDScript 4 permits it as an array type parameter in this project's Godot version before applying.

---

### Minor — M2: `show_move_range()` does not clear `_hovered_path`

**Location:** Lines 31–45 (`show_move_range`)

**Issue:** When `show_move_range()` is called to start a new move action, `_highlight_cells` is cleared but `_hovered_path` is not reset. If `show_move_range()` is called while `_hovered_path` is non-empty from a previous interaction, the stale path will be visible in `_draw()` for one frame (until the first `InputEventMouseMotion` fires and overwrites it).

This scenario is not covered by EC3, which only addresses transitions from CELLS to a non-CELLS mode. A transition from CELLS → (another call to) CELLS would leave a stale path briefly visible.

**Risk:** Low in practice — the stale flash is one frame and only occurs if `show_move_range()` is called twice without an intervening `clear()`. However, it is a subtle correctness gap.

**Fix:** Add `_hovered_path = []` to `show_move_range()` alongside the existing `.clear()` calls:
```gdscript
func show_move_range(baller: Node) -> void:
    _mode = Mode.CELLS
    _highlight_cells.clear()
    _highlight_ballers.clear()
    _hovered_path = []          # add this line
    ...
```

---

## Non-Issues (Items Investigated and Cleared)

**Drawing order:** The spec's rendering table lists MOVE_FILL, MOVE_EDGE, PATH_DOT, PATH_RING as four sequential passes. The implementation draws fill and edge in the same per-cell loop (fill+edge per cell), then dots, then ring. The end result is that all path dots and the ring render on top of all cell rectangles, which matches the spec's intent. The per-cell interleaving of fill and edge does not affect correctness.

**Null safety (`_hovered_path.back()`):** `.back()` is guarded by `if not _hovered_path.is_empty()` immediately before the call. No crash path exists.

**Null safety (path elements):** `get_path_to_cell()` is only called when `grid_pos` is confirmed to be in `_highlight_cells`, and the spec states BFS guarantees a path exists for every reachable cell (EC2). Null elements in the returned array are not a realistic concern given existing GridManager contracts.

**Event ordering:** The `InputEventMouseMotion` branch (line 186) appears before the `InputEventMouseButton` left-click branch (line 196). Motion events cannot fall through to click logic.

**Mode guard on motion branch:** `if event is InputEventMouseMotion and _mode == Mode.CELLS:` — double-guarded by both event type and mode.

**Input consumption:** `return` on line 194 exits without calling `get_viewport().set_input_as_handled()`. B5 is fully satisfied.

**Only file modified:** The diff touches only `TargetOverlay.gd`, consistent with the spec's "Files Changed" section and Non-Goal 8 (no `BattleDemo` changes).

---

## Summary

The implementation is correct and safe. Both findings are Minor style/robustness issues that do not cause incorrect behavior under normal game flow. M1 is a CLAUDE.md style compliance issue. M2 is a one-frame stale-render edge case that only manifests if `show_move_range()` is called consecutively without `clear()` in between.

Recommend fixing both before merge but neither blocks Stage 5 integration testing.
