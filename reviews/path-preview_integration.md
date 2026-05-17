# Integration Report: path-preview

**Verdict: PASS**

**All findings resolved.** The original FAIL (BFS cache race condition) has been fixed and re-verified. See Q2 below for details.

---

## Q1 — BFS Cache Lifetime During TARGET_MOVE

**Status: PASS (under normal conditions)**

`show_move_range()` calls `GridManager.mark_reachable_cells()` once, which sets `pf_root` backpointers on all reachable cells. These backpointers live directly on the `GridCell` objects in `GridManager._grid` and are never touched again until the next `mark_reachable_cells()` call (which begins with `reset_all_markers()`).

As long as no other code calls `mark_reachable_cells()` or `reset_all_markers()` during the player's targeting session, `get_path_to_cell()` has valid backpointers on every hover event throughout the full `TARGET_MOVE` session.

**Conclusion:** Cache is valid for the entire session — provided no concurrent caller clobbers it.

---

## Q2 — Enemy BFS Interference During TARGET_MOVE

**Status: PASS — RESOLVED (was: FAIL)**

**Original finding:** `EnemyAI._move_one_step_toward()` (called from `EnemyAI.update_enemy_movement()` → `BeatManager._resolve_enemy_movement()` → `BeatManager.end_beat()`) calls `GridManager.mark_reachable_cells()`, which unconditionally calls `reset_all_markers()` and zeros every `pf_root` and `pf_distance` on the grid. Because Godot signals are synchronous, `end_beat()` (including enemy BFS) could execute during the player's `TARGET_MOVE` session, leaving `get_path_to_cell()` returning a path that terminates at the origin cell rather than the hovered target.

**Fix applied (re-verified 2026-05-17):** In `TargetOverlay._unhandled_input()`, after calling `get_path_to_cell()`, the result is validated before being assigned to `_hovered_path`:

```gdscript
var path: Array[GridManager.GridCell] = GridManager.get_path_to_cell(grid_pos.x, grid_pos.y)
# Validate destination — stale BFS cache (wiped by enemy move) returns a
# path that doesn't reach the intended cell; discard it silently.
if not path.is_empty() and path.back().col == grid_pos.x and path.back().row == grid_pos.y:
    _hovered_path = path
else:
    _hovered_path = []
```

**Verification of fix correctness:**

- **Stale-BFS case (garbage path):** When `reset_all_markers()` has wiped `pf_root` pointers, `get_path_to_cell()` returns a path whose final element does not match the hovered cell. The destination check fails; `_hovered_path = []`. `_draw()` iterates `range(1, 0)` — no step dots. The `not _hovered_path.is_empty()` guard suppresses the destination ring. No visual glitch.
- **Valid-BFS case (good path):** `get_path_to_cell()` returns a correctly-terminated path. Both `.col` and `.row` match `grid_pos`; `_hovered_path = path` is assigned normally. Draw loop renders step dots and destination ring as intended.
- **Empty-path edge case:** `not path.is_empty()` short-circuits before the `.back()` access; `else` branch assigns `_hovered_path = []`. Safe.
- **No new issues:** No new resource references, no side effects, no changes to event consumption (the `return` at line 201 without `set_input_as_handled()` is unchanged, preserving B5 compliance confirmed in Q3).

---

## Q3 — BattleDemo Wire-up: Do Hover Events Reach TargetOverlay._unhandled_input?

**Status: PASS**

`TargetOverlay._ready()` calls `set_process_unhandled_input(false)`. `show_move_range()` calls `set_process_unhandled_input(true)` before returning.

`BattleDemo._set_ui_state(UIState.TARGET_MOVE)` calls `_target_overlay.show_move_range(...)`, which enables unhandled input on the overlay. `BattleDemo._input()` handles `InputEventMouseMotion` only when `_ui_state == UIState.IDLE or UIState.BALLER_SELECTED` (line 704), and it does *not* call `get_viewport().set_input_as_handled()` for mouse-motion events, so motion events are not consumed there.

`BattleDemo._setup_state_input(TARGET_MOVE)` falls through to the `_:` branch which does nothing — it neither enables nor disables `BattleDemo`'s own unhandled input processing.

`TargetOverlay._unhandled_input()` returns early (but does not consume the event) for mouse-motion in `Mode.CELLS`, satisfying B5. The overlay is a child of `_court` (a Node2D), not a CanvasLayer, so there is no z-order input blocking issue.

**Conclusion:** Mouse motion events reach `TargetOverlay._unhandled_input` correctly during `TARGET_MOVE` with no changes to `BattleDemo`.

---

## Q4 — AbilitySystem.initiate_move() Path Order

**Status: PASS**

`AbilitySystem.initiate_move()` (line 31) calls:

```
MovementSystem.set_path(baller, GridManager.get_path_to_cell(destination.x, destination.y))
```

This call uses the `pf_root` backpointers that were set by `GridManager.mark_reachable_cells()` inside `TargetOverlay.show_move_range()`. It does *not* call `mark_reachable_cells()` itself. The BFS cache is still valid at the point of the click because no reset has occurred between `show_move_range()` and the click handler.

The path stored by `MovementSystem.set_path()` is an independent `Array` of `GridCell` object references (`.slice(1)`). Even if `mark_reachable_cells()` is called later and mutates the `pf_root` fields, the `Array` stored in `MovementSystem._paths` still holds the correct ordered cell references (the cells themselves are not re-created, only their `pf_root` fields are overwritten). So `continue_movement()` will step through the correct sequence of cells regardless.

**The hover path and the committed path match** because both use the same BFS result. The hover path (`_hovered_path`) and the move path passed to `set_path()` are both derived from the same `get_path_to_cell()` call on the same BFS state.

---

## Q5 — clear_preview() vs. _hovered_path

**Status: PASS**

`clear_preview()` is:

```gdscript
func clear_preview() -> void:
    if _mode == Mode.PREVIEW_ENEMIES or _mode == Mode.PREVIEW_CELLS:
        clear()
```

It only calls `clear()` if the current mode is `PREVIEW_ENEMIES` or `PREVIEW_CELLS`. During `TARGET_MOVE`, `_mode == Mode.CELLS`. Therefore, `clear_preview()` is a no-op when called during move targeting and does **not** touch `_hovered_path`.

`BattleDemo` connects `_action_menu.action_unhovered` to `_target_overlay.clear_preview()`. This fires when the mouse leaves an ActionMenu button. The ActionMenu is hidden (`hide_menu()`) before `show_move_range()` is called (line 377: `_action_menu.hide_menu()` is called inside `_set_ui_state(TARGET_MOVE)`), so `action_unhovered` cannot fire during `TARGET_MOVE` — the menu is not visible.

**Double-protected:** Even if `action_unhovered` somehow fired during `TARGET_MOVE`, `clear_preview()` would be a no-op because `_mode` would be `Mode.CELLS`, not a preview mode.

`clear()` (called by other paths) does clear `_hovered_path`, which is correct per spec B6.

---

## Q6 — No BattleDemo Changes Required

**Status: PASS**

The spec's claim is confirmed. The evidence:

1. `show_move_range()` enables `set_process_unhandled_input(true)` on `TargetOverlay` internally — no BattleDemo hook needed.
2. `BattleDemo._input()` does not consume `InputEventMouseMotion` events, so they propagate to `_unhandled_input` on child nodes.
3. `_set_ui_state(TARGET_MOVE)` already calls `show_move_range()`, which sets up all necessary state.
4. `TargetOverlay.clear()` (called by `_set_ui_state(IDLE)`) already zeros `_hovered_path`.
5. No new signals, no new node references, and no new wiring in `_wire_signals()` are needed.

---

## Summary Table

| # | Question | Status | Notes |
|---|---|---|---|
| Q1 | BFS cache lifetime | PASS | Valid throughout session unless external caller resets |
| Q2 | Enemy BFS interference | **PASS** | Fixed: destination-check guard in `_unhandled_input` discards stale-BFS paths; re-verified 2026-05-17 |
| Q3 | BattleDemo hover wire-up | PASS | Events reach overlay correctly; no BattleDemo changes needed |
| Q4 | initiate_move() path order | PASS | Uses cached BFS; committed path matches hover path |
| Q5 | clear_preview() vs _hovered_path | PASS | clear_preview() is a no-op during CELLS mode |
| Q6 | No BattleDemo changes | PASS | Confirmed; spec constraint upheld |

---

## Fix Applied for Q2

The destination-check guard described above was implemented in `TargetOverlay._unhandled_input()` (lines 192–197 of `TargetOverlay.gd`). The fix is minimal, self-contained, and requires no changes to `EnemyAI`, `GridManager`, or `BeatManager`. It handles both the narrow current race window (last action of a beat) and any future widened window (timer-based or AI-triggered beat endings).
