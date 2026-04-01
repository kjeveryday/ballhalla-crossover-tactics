# Step 18 — Enemy Information + Guard Display

**Depends on:** Steps 15–17
**Required by:** Step 19 (EnemyInfoPanel dismiss-on-ActionMenu logic)

## Goal

Players can inspect enemies before acting against them, and can see defensive matchups drawn on the court at a glance.

---

## 18A — `EnemyInfoPanel.gd`

**Location:** `scenes/battle/EnemyInfoPanel.gd`
**Type:** Control, child of HUD CanvasLayer (added after ActionMenu so it renders on top)

### Public API

```gdscript
signal closed()

func show_for_enemy(enemy: Node, screen_pos: Vector2) -> void
func hide_panel() -> void
```

### Layout

Styled identically to ActionMenu (same `StyleBoxFlat` constants — consider sharing a `UIStyle.gd` constants file). Contents:

```
┌─────────────────────────┐
│ Hollywood PG   [ENEMY]  │
│ Zone: MIDRANGE          │
├─────────────────────────┤
│ STM ████████░░  82/100  │
├─────────────────────────┤
│ Guards: Remix PG        │
│ Off Rating: 72          │
│ Def Rating: 65          │
│ Hype Resist: medium     │
└──────────────────[ × ]──┘
```

Width: 180px. Height: auto. Positioned to the right of the clicked token with the same `_clamped()` logic from ActionMenu.

### Dismiss triggers

- `×` button pressed
- ESC key (handled in `_unhandled_input`)
- `BattleDemo._set_ui_state(BALLER_SELECTED)` calls `_enemy_info_panel.hide_panel()` — only one of ActionMenu or EnemyInfoPanel visible at once
- Step 21 TransitionScreen showing calls `hide_panel()`

### Mouse cursor

In BattleDemo `_input()`, detect mouse hover over enemy tokens (using the same distance check as allied selection). When hovering:
```gdscript
Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
```
Reset to `CURSOR_ARROW` on mouse_exit. This gives a click affordance without a tooltip.

---

## 18B — `GuardDisplay.gd`

**Location:** `scenes/battle/GuardDisplay.gd`
**Type:** Node2D, child of `_court` (below TargetOverlay in child order)

### Drawing

```gdscript
func _draw() -> void:
    for enemy in EnemyTeam.get_active_ballers():
        var target: Node = enemy.guard_assignment
        if target == null:
            continue
        _draw_dashed_line(enemy.position, target.position,
            Color(0.45, 0.55, 0.80, 0.55), 1.5, 8.0, 5.0)

func _draw_dashed_line(from: Vector2, to: Vector2,
        color: Color, width: float, dash: float, gap: float) -> void:
    var total: float = from.distance_to(to)
    var dir: Vector2 = (to - from).normalized()
    var pos: float = 0.0
    while pos < total:
        var end: float = min(pos + dash, total)
        draw_line(from + dir * pos, from + dir * end, color, width)
        pos += dash + gap
```

### Refresh triggers

```gdscript
func _ready() -> void:
    BeatManager.beat_ended.connect(queue_redraw)
    BeatManager.beat_started.connect(queue_redraw)
```

### D-key toggle cycle in BattleDemo

Replace the binary zone overlay toggle with a 4-state cycle:

```gdscript
var _debug_mode: int = 0
# 0 = none, 1 = zone only, 2 = zone + guards, 3 = guards only

# In _input() KEY_D:
_debug_mode = (_debug_mode + 1) % 4
_zone_overlay.visible = _debug_mode == 1 or _debug_mode == 2
_guard_display.visible = _debug_mode == 2 or _debug_mode == 3
```

---

## 18C — Enemy Click Detection in BattleDemo

Add enemy click detection in `_input()` when `_ui_state == IDLE` or `BALLER_SELECTED`:

```gdscript
# After allied baller click check:
for enemy in _enemies:
    if court_pos.distance_to(enemy.position) <= GridManager.CELL_SIZE * 0.45:
        _enemy_info_panel.show_for_enemy(enemy, event.position)
        if _ui_state == UIState.BALLER_SELECTED:
            _action_menu.hide_menu()
        get_viewport().set_input_as_handled()
        return
```

---

## Files Changed

| File | Change |
|------|--------|
| `scenes/battle/EnemyInfoPanel.gd` | New file |
| `scenes/battle/GuardDisplay.gd` | New file |
| `scenes/battle/BattleDemo.gd` | Add `_enemy_info_panel` and `_guard_display` nodes; add enemy click detection; extend D-key to 4-state cycle; add `_debug_mode` var |

---

## Testing Checklist

- [ ] Click enemy → EnemyInfoPanel appears with correct stats
- [ ] EnemyInfoPanel shows correct guard assignment name
- [ ] EnemyInfoPanel shows "Unassigned" when guard_assignment is null (post-screen)
- [ ] Clicking an allied baller while EnemyInfoPanel is open closes it and opens ActionMenu
- [ ] Opening ActionMenu while EnemyInfoPanel is open closes EnemyInfoPanel
- [ ] ESC closes EnemyInfoPanel
- [ ] D key cycles through 4 modes: none → zones → zones+guards → guards only
- [ ] Guard lines update after each beat end (enemy movement)
- [ ] Guard lines show "Unassigned" as no line for that enemy
