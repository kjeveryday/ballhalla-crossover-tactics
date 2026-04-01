# Step 19 — ActionMenu UX Polish + Hover Previews

**Depends on:** Steps 15–18
**Required by:** Step 20 (Undo button state from Step 22 lives here)

## Goal

Players know what each action costs and which targets it affects before committing. Keyboard shortcuts are visible in the menu. Play calls include descriptions.

---

## 19A — Keyboard Shortcut Hints on Buttons

In `ActionMenu._make_btn()`, append the shortcut as right-aligned text. The simplest approach without a custom draw call is to use a tab-padded format. Define a helper:

```gdscript
func _btn_label(text: String, shortcut: String) -> String:
    # Pad text to ~18 chars, then append shortcut
    return text.rpad(18) + shortcut
```

Update button label definitions in `_build_main_panel()`:
```gdscript
var actions := [
    ["move",     _btn_label("Move  ▸",      "[M]"),  C_TEXT],
    ["pass",     _btn_label("Pass  ▸",      "[P]"),  C_TEXT],
    ["shoot",    _btn_label("Shoot",        "[S]"),  C_TEXT],
    ["screen",   _btn_label("Screen",       "[X]"),  C_TEXT],
    ["talk",     _btn_label("Talk  ▸",      "[T]"),  C_TEXT],
    ["playcall", _btn_label("Play Call  ▸", "[1-4]"), C_TEXT_HOT],
]
```

End Turn: `_btn_label("End Turn", "[Space]")`

Play Call submenu buttons:
```gdscript
["play:pick_and_roll",  _btn_label("Pick & Roll",  "[1]"), C_TEXT_HOT],
["play:give_and_go",    _btn_label("Give & Go",    "[2]"), C_TEXT_HOT],
["play:iso",            _btn_label("ISO",          "[3]"), C_TEXT_HOT],
["play:drive_and_kick", _btn_label("Drive & Kick", "[4]"), C_TEXT_HOT],
```

> Note: `rpad()` only works reliably with a monospace font. The fallback font is monospace by default in Godot 4. If it wraps oddly, use a fixed-size secondary Label instead.

---

## 19B — Stamina Cost Labels

Add a small cost annotation to each button. Approach: make `_make_btn()` accept an optional `cost_text: String` parameter and add a second smaller Label inside the button.

```gdscript
const ACTION_COSTS := {
    "move":      "10 STM",
    "pass":      "10 STM",
    "shoot":     "10 STM",
    "screen":    "10 STM",
    "trash_talk":"5 STM",
    "leadership":"5 STM",
    "iso_talk":  "8 STM",
    "end_turn":  "free",
    "playcall":  "first action",
}
```

Cost label: font size 10, color `Color(0.55, 0.65, 0.55)` (muted green), positioned at bottom-right of button. "free" shown in a slightly lighter color.

For disabled buttons, cost label also uses `C_TEXT_DIS`.

---

## 19C — Hover Preview in TargetOverlay

### New TargetOverlay modes

Extend the `Mode` enum:
```gdscript
enum Mode { NONE, CELLS, BALLERS, PREVIEW_ENEMIES, PREVIEW_CELLS }
```

Preview modes draw tinted overlays but **never intercept input** (`set_process_unhandled_input(false)` in all preview modes).

New methods:
```gdscript
func preview_trash_range(baller: Node) -> void:
    # Show enemies within distance 5 in orange
    _mode = Mode.PREVIEW_ENEMIES
    _highlight_ballers.clear()
    for enemy in EnemyTeam.get_active_ballers():
        if GridManager.chebyshev_distance(
                baller.grid_col, baller.grid_row,
                enemy.grid_col, enemy.grid_row) <= 5:
            _highlight_ballers.append(enemy)
    set_process_unhandled_input(false)
    queue_redraw()

func preview_screen_target(baller: Node) -> void:
    # Show the enemy currently guarding this baller
    _mode = Mode.PREVIEW_ENEMIES
    _highlight_ballers.clear()
    for enemy in EnemyTeam.get_active_ballers():
        if enemy.guard_assignment == baller:
            _highlight_ballers.append(enemy)
    set_process_unhandled_input(false)
    queue_redraw()

func preview_move_range(baller: Node) -> void:
    _mode = Mode.PREVIEW_CELLS
    # Same computation as show_move_range but no input interception
    _highlight_cells.clear()
    var cells := GridManager.get_cells_in_range(baller.grid_col, baller.grid_row, 3)
    for cell in cells:
        if cell.occupant == null or cell.occupant == baller:
            _highlight_cells.append(Vector2i(cell.col, cell.row))
    set_process_unhandled_input(false)
    queue_redraw()

func clear_preview() -> void:
    if _mode in [Mode.PREVIEW_ENEMIES, Mode.PREVIEW_CELLS]:
        clear()
```

Preview colors (distinct from interactive colors):
- `C_PREVIEW_ENEMY := Color(1.0, 0.45, 0.1, 0.35)` — orange fill
- `C_PREVIEW_ENEMY_EDGE := Color(1.0, 0.55, 0.15, 0.80)` — orange ring
- `C_PREVIEW_CELL := Color(0.15, 0.55, 1.00, 0.18)` — same blue but lower alpha

### ActionMenu signals

Add to `ActionMenu.gd`:
```gdscript
signal action_hovered(action_id: String)
signal action_unhovered()
```

In `_make_btn()`:
```gdscript
btn.mouse_entered.connect(func(): action_hovered.emit(action_id))
btn.mouse_exited.connect(func(): action_unhovered.emit())
```

### BattleDemo wiring

```gdscript
_action_menu.action_hovered.connect(_on_action_hovered)
_action_menu.action_unhovered.connect(func(): _target_overlay.clear_preview())

func _on_action_hovered(action_id: String) -> void:
    if _is_animating:
        return
    var sel := _selected_baller()
    match action_id:
        "move":
            _target_overlay.preview_move_range(sel)
        "screen":
            _target_overlay.preview_screen_target(sel)
        "trash_talk":
            _target_overlay.preview_trash_range(sel)
        _:
            _target_overlay.clear_preview()
```

---

## 19D — Play Call Description Tooltip

In `ActionMenu._build_play_panel()`, add a description Label below the Back button:

```gdscript
var _play_desc_label: Label

# In _build_play_panel(), after Back button:
vbox.add_child(_make_sep())
_play_desc_label = Label.new()
_play_desc_label.custom_minimum_size = Vector2(PANEL_W - PAD * 2, 36)
_play_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
_play_desc_label.add_theme_font_size_override("font_size", 11)
_play_desc_label.add_theme_color_override("font_color", Color(0.60, 0.65, 0.70))
_play_desc_label.text = "Hover a play to see details"
vbox.add_child(_play_desc_label)
```

In play button `mouse_entered` callbacks, update `_play_desc_label.text`:
```gdscript
const PLAY_DESCRIPTIONS := {
    "play:pick_and_roll":  "+15% shot\nafter Screen→Cut→Pass",
    "play:give_and_go":    "+10 hype to cutter\nafter Pass→Cut→Pass",
    "play:iso":            "+20% shot\nafter ISO→Move",
    "play:drive_and_kick": "+10% shot + free STM\nafter Move→Pass",
}
```

---

## 19E — Improved `_update_availability()`

```gdscript
func _update_availability() -> void:
    if _baller == null:
        return

    var has_ball: bool   = _baller.has_ball
    var can_act: bool    = _baller.can_act()
    var is_first: bool   = BeatManager.actions_remaining == BeatManager.ACTIONS_PER_BEAT

    # Check if screen has a valid target
    var has_screen_target: bool = false
    for enemy in EnemyTeam.get_active_ballers():
        if enemy.guard_assignment == _baller:
            has_screen_target = true
            break

    # Check if leadership has a valid target
    var has_leadership_target: bool = false
    for b in AlliedTeam.get_active_ballers():
        if b != _baller and not b.is_exhausted:
            has_leadership_target = true
            break

    _set_btn_enabled("move",     can_act)
    _set_btn_enabled("pass",     can_act and has_ball)
    _set_btn_enabled("shoot",    can_act and has_ball)
    _set_btn_enabled("screen",   can_act and has_screen_target)
    _set_btn_enabled("playcall", can_act and is_first)

    # Disable all if exhausted
    if not can_act:
        for key in _main_btns.keys():
            _set_btn_enabled(key, false)
```

---

## Files Changed

| File | Change |
|------|--------|
| `scenes/battle/ActionMenu.gd` | Add shortcut hints, cost labels, `action_hovered/unhovered` signals, play description label, improved `_update_availability()` |
| `scenes/battle/TargetOverlay.gd` | Add PREVIEW_ENEMIES, PREVIEW_CELLS modes; add `preview_trash_range()`, `preview_screen_target()`, `preview_move_range()`, `clear_preview()` |
| `scenes/battle/BattleDemo.gd` | Wire `action_hovered/unhovered`; add `_on_action_hovered()` |

---

## Testing Checklist

- [ ] All buttons show keyboard shortcut right-aligned
- [ ] All buttons show stamina cost
- [ ] Hover "Move" → blue cell range preview appears on court
- [ ] Hover "Screen" → target enemy highlighted in orange
- [ ] Hover "Trash Talk" → all in-range enemies highlighted in orange
- [ ] Unhovering any button clears preview immediately
- [ ] Preview never intercepts clicks (TargetOverlay stays non-interactive)
- [ ] Hover play buttons → description appears at bottom of play panel
- [ ] Exhausted baller → all buttons disabled
- [ ] Screen disabled when no enemy is guarding the selected baller
