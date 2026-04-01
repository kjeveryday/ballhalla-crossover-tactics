# Step 22 — Game Flow QoL: Undo, Tab, Confirmation, Turnover Fix, Log Panel

**Depends on:** Steps 15–21
**Required by:** Nothing (final step)

## Goal

Eliminate the remaining rough edges in the game loop: fix the turnover stall bug, give players an undo for misclicks, make navigation smarter, prevent accidental beat-ends, and surface the full event history.

---

## 22A — Turnover Fix (do this first — it's an active stall bug)

### Current state
`AbilitySystem._handle_turnover()` just drops the ball and prints a TODO. The game never ends the possession. Players are stuck.

### Fix: `AbilitySystem.gd`

```gdscript
signal turnover_occurred(baller: Node)

func _handle_turnover(baller: Node) -> void:
    baller.has_ball = false
    print("[TURNOVER] %s — possession ends" % baller.stats.display_name)
    turnover_occurred.emit(baller)
    # End the beat action cleanly, then end possession
    BeatManager.spend_action("turnover")
    QuarterManager.end_possession()
```

> `spend_action("turnover")` will call `end_beat()` if this was the last action. That's fine — `end_possession()` handles state cleanup.
> If the possession is already ending mid-beat, `end_possession()` is idempotent through `_reset_ballers_for_next_possession()`.

### BattleDemo wiring
`AbilitySystem.turnover_occurred` → `FloatingTextSpawner.spawn_event(baller.position, "TURNOVER!")` (already planned in Step 15).

---

## 22B — Undo Move

### State stored in BattleDemo

```gdscript
var _undo_snapshot: Dictionary = {}
# { baller: Node, col: int, row: int, stamina: int, actions_was: int }

var _undo_available: bool = false
```

### Snapshot capture

In `_on_action_chosen("move")`, before calling `AbilitySystem.initiate_move()`:

```gdscript
func _capture_undo_snapshot(baller: Node) -> void:
    _undo_snapshot = {
        baller = baller,
        col = baller.grid_col,
        row = baller.grid_row,
        stamina = baller.current_stamina,
        actions_was = BeatManager.actions_remaining,
        position = baller.position,  # visual position too
    }
    _undo_available = true
```

### Undo execution

```gdscript
func _execute_undo() -> void:
    if not _undo_available:
        return
    var snap: Dictionary = _undo_snapshot
    var b: Node = snap.baller

    b.grid_col = snap.col
    b.grid_row = snap.row
    b.position = snap.position       # Snap visual back instantly
    b.current_stamina = snap.stamina
    b.acted_this_beat = false
    b.consecutive_actions = max(0, b.consecutive_actions - 1)
    BeatManager.actions_remaining = snap.actions_was

    _undo_available = false
    _undo_snapshot = {}
    _set_ui_state(UIState.IDLE)
    _refresh_status()
    _log("Undo: move reversed")
```

### Clearing the snapshot

Set `_undo_available = false` on:
- `BeatManager.beat_ended` — beat is over, can't undo
- `ShotSystem.shot_made` — irreversible
- `ShotSystem.shot_missed` — irreversible
- `AbilitySystem.pass_completed` — irreversible
- `AbilitySystem.turnover_occurred` — irreversible

### Undo button in ActionMenu

In Step 19's ActionMenu, add an "Undo" button below End Turn (hidden by default):

```gdscript
var _undo_btn: Button

# In _build_main_panel(), after End Turn button:
_undo_btn = _make_btn(_btn_label("Undo Move", "[Ctrl+Z]"), "undo", C_TEXT)
_undo_btn.visible = false
vbox.add_child(_undo_btn)
_main_btns["undo"] = _undo_btn
```

`show_for_baller()` sets `_undo_btn.visible = BattleDemo._undo_available` — pass this as a parameter or read from a passed context dict.

### Keyboard shortcut

In `BattleDemo._input()`:
```gdscript
if event is InputEventKey and event.pressed and event.keycode == KEY_Z:
    if event.ctrl_pressed:
        _execute_undo()
```

---

## 22C — Tab to Next Available Baller

In `BattleDemo._input()`, handle `KEY_TAB`:

```gdscript
KEY_TAB:
    _select_next_available_baller()

func _select_next_available_baller() -> void:
    var start: int = _selected_idx
    for offset in range(1, 6):
        var idx: int = (start + offset) % 5
        var b: Node = _ballers[idx]
        if not b.acted_this_beat and not b.is_exhausted:
            _selected_idx = idx
            _refresh_status()
            _set_ui_state(UIState.BALLER_SELECTED)
            return
    _log("All ballers have acted this beat")
```

Also add Tab shortcut hint to the hint bar at the bottom of the screen.

---

## 22D — End Beat Confirmation Dialog

### `ConfirmDialog.gd`

**Location:** `scenes/battle/ConfirmDialog.gd`
**Type:** Control, child of HUD CanvasLayer

Small centered dialog, same StyleBoxFlat styling:

```
┌──────────────────────────────────┐
│  End beat with 2 action(s)?      │
│  ────────────────────────────    │
│       [ Yes ]      [ No ]        │
└──────────────────────────────────┘
```

Width: 260px, Height: 90px. `mouse_filter = STOP`.

```gdscript
signal confirmed()
signal cancelled()

func show_confirm(message: String) -> void:
    _label.text = message
    visible = true

func _on_yes() -> void:
    visible = false
    confirmed.emit()

func _on_no() -> void:
    visible = false
    cancelled.emit()

func _unhandled_input(event: InputEvent) -> void:
    if not visible: return
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_Y or event.keycode == KEY_ENTER:
            _on_yes()
        elif event.keycode == KEY_N or event.keycode == KEY_ESCAPE:
            _on_no()
```

### BattleDemo integration

Replace the `KEY_ENTER` handler:

```gdscript
KEY_ENTER, KEY_KP_ENTER:
    if BeatManager.actions_remaining > 0:
        _confirm_dialog.show_confirm(
            "End beat with %d action(s) unused?" % BeatManager.actions_remaining)
        _confirm_dialog.confirmed.connect(
            func(): BeatManager.end_beat_early(), CONNECT_ONE_SHOT)
    else:
        BeatManager.end_beat_early()
```

---

## 22E — Scrollable Match Log Panel

### `LogPanel.gd`

**Location:** `scenes/battle/LogPanel.gd`
**Type:** Control, child of HUD CanvasLayer
**Position:** Right side of screen (200px wide, full height minus top HUD)
**Default:** Hidden (toggle with L key)

```gdscript
const LOG_COLORS := {
    "score":     "[color=#88ff88]",   # green
    "miss":      "[color=#ff6666]",   # red
    "play":      "[color=#ffdd44]",   # yellow
    "quarter":   "[color=#ffffff]",   # white
    "stamina":   "[color=#ffaa44]",   # orange
    "turnover":  "[color=#ff4444]",   # bright red
    "default":   "[color=#bbbbbb]",   # light gray
}

func append(msg: String, category: String = "default") -> void:
    var color_tag: String = LOG_COLORS.get(category, LOG_COLORS["default"])
    _rich_text.append_text(color_tag + msg + "[/color]\n")
    # Auto-scroll to bottom
    await get_tree().process_frame
    _scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value
```

Internal structure: Panel → ScrollContainer → RichTextLabel (bbcode_enabled = true, fit_content = false).

Add a small "LOG" toggle button pinned at right edge of screen (always visible even when panel is hidden) that toggles the panel.

### BattleDemo integration

Modify `_log()` to also push to the log panel:

```gdscript
func _log(msg: String, category: String = "default") -> void:
    _log_lines.append(msg)
    if _log_lines.size() > 7:
        _log_lines.pop_front()
    _log_label.text = "\n".join(_log_lines)
    _log_panel.append(msg, category)
```

Pass categories from the call sites:
```gdscript
_log("MADE +%dpts! (%s)" % [points, name], "score")
_log("Missed shot (%s)" % name, "miss")
_log("PLAY TRIGGERED: %s!" % pname, "play")
_log("=== Q%d ENDED ===" % q, "quarter")
```

### L key toggle

```gdscript
KEY_L:
    _log_panel.visible = not _log_panel.visible
```

---

## 22F — Shortcut Reference Overlay

### `ShortcutRef.gd`

**Location:** `scenes/battle/ShortcutRef.gd`
**Type:** Control, child of HUD CanvasLayer

Shown on `?` key, dismissed by any keypress.

Two-column grid layout of all shortcuts:

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| Click | Select baller | Tab | Next available |
| M | Move | P | Pass |
| S | Shoot | X | Screen |
| T | Trash Talk | L | Leadership |
| I | ISO | 1–4 | Play calls |
| Space | End Turn | Enter | End Beat |
| D | Toggle overlay | Ctrl+Z | Undo |
| ESC | Cancel | L | Log panel |
| ? | This screen | — | — |

Background: semi-transparent dark overlay. Any keypress hides it.

---

## Files Changed

| File | Change |
|------|--------|
| `autoloads/AbilitySystem.gd` | Add `turnover_occurred` signal; fix `_handle_turnover()` to call `end_possession()` |
| `scenes/battle/ConfirmDialog.gd` | New file |
| `scenes/battle/LogPanel.gd` | New file |
| `scenes/battle/ShortcutRef.gd` | New file |
| `scenes/battle/BattleDemo.gd` | Add undo snapshot/execute; add `_select_next_available_baller()`; replace Enter handler with confirmation; add `_log_panel` node; add `_confirm_dialog` node; add `_shortcut_ref` node; wire `turnover_occurred`; update `_log()` signature |
| `scenes/battle/ActionMenu.gd` | Add Undo button (hidden by default); update `show_for_baller()` to accept/check undo availability |

---

## Testing Checklist

**Turnover fix:**
- [ ] Pass with high turnover_chance → "TURNOVER!" floats up
- [ ] Defense phase screen appears after turnover
- [ ] Game does not stall after a turnover

**Undo:**
- [ ] Move then Ctrl+Z → baller snaps back to original position
- [ ] Stamina restored after undo
- [ ] Actions remaining restored after undo
- [ ] Undo button visible in ActionMenu after a move
- [ ] Undo cleared after shot/pass/beat end
- [ ] Pass and Shoot disabled while undo is available
- [ ] Cannot undo non-move actions

**Tab cycling:**
- [ ] Tab skips exhausted ballers
- [ ] Tab skips acted-this-beat ballers
- [ ] Tab wraps correctly
- [ ] "All ballers acted" message when none available

**End beat confirmation:**
- [ ] Enter with 2 actions remaining → dialog appears
- [ ] Y confirms, N cancels
- [ ] Enter with 0 actions → no dialog, end beat immediately
- [ ] ESC in dialog cancels without ending beat

**Log panel:**
- [ ] L key toggles log panel
- [ ] Log panel shows all events with correct colors
- [ ] Auto-scrolls to bottom on new entry
- [ ] Rolling 7-line label still works alongside log panel

**Shortcut reference:**
- [ ] ? key shows reference overlay
- [ ] Any keypress dismisses it
