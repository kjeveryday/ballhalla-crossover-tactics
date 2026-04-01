# Step 20 — HUD Overhaul: Scoreboard, Active Play Banner, Baller Info Bar, Hype FX

**Depends on:** Steps 15–19
**Required by:** Step 21 (TransitionScreen hides these panels before showing)

## Goal

Replace the dense status string with purpose-built panels. Critical information is always visible without reading a packed text line. Add a hype milestone effect that makes big momentum shifts feel dramatic.

---

## 20A — `ScoreboardPanel.gd`

**Location:** `scenes/battle/ScoreboardPanel.gd`
**Type:** Control, child of HUD CanvasLayer
**Position:** Top-center of screen (anchored CENTER_TOP)

### Layout

```
┌──────────────────────────────────────┐
│  REMIX   6  |  Q2  Beat 3/8  |  8  STARS  │
│             ◀  ALLIED POSSESSION           │
└──────────────────────────────────────┘
```

Width: 400px. Height: 52px. Centered horizontally.

Internal structure: HBoxContainer with three sections (left team, center info, right team). Center shows `Q{n}  Beat {b}/8`. Possession arrow (◀ or ▶) below center.

### Signals to connect

```gdscript
func _ready() -> void:
    QuarterManager.score_changed.connect(_on_score_changed)
    QuarterManager.quarter_ended.connect(func(_q): _refresh())
    BeatManager.beat_started.connect(func(_n): _refresh())
```

### Possession arrow logic

Allied possession (GameStateMachine in OFFENSE_START or SELECTING_*) → show ◀ in team color.
Defense phase → show ▶ in enemy color.
Arrow updates on `GameStateMachine.state_changed`.

---

## 20B — `ActivePlayBanner.gd`

**Location:** `scenes/battle/ActivePlayBanner.gd`
**Type:** Control, child of HUD CanvasLayer
**Position:** Below ScoreboardPanel, centered

Only visible when `PlayManager.active_play != null`.

### Layout

```
▶  PICK & ROLL  —  Beat 2 of 3 active
```

Pill shape with rounded corners. Gold/yellow color. Width: 300px. Height: 28px.

### Beat counter

Track `_play_beat_start: int` set when `play_called` fires:
```gdscript
var _play_beat_start: int = 0

func _on_play_called(_name: String) -> void:
    _play_beat_start = BeatManager.current_beat
    visible = true
    _refresh_text()

func _on_beat_ended(_n: int) -> void:
    if visible:
        _refresh_text()

func _refresh_text() -> void:
    var elapsed: int = BeatManager.current_beat - _play_beat_start
    _label.text = "▶  %s  —  Beat %d active" % [
        PlayManager.active_play.play_name, elapsed + 1]
```

### Flash on trigger/expire

On `play_triggered`: flash green for 0.4s (modulate tween), then hide.
On `play_expired`: flash red for 0.3s, then hide.

---

## 20C — `BallerInfoBar.gd`

**Location:** `scenes/battle/BallerInfoBar.gd`
**Type:** Control, child of HUD CanvasLayer
**Position:** Below shot clock bar, left-aligned (replaces `_status_label`)

### Layout

```
► Remix PG  [BALL]   STM ████████░░  Hype ███░░░░░░░  Actions ●●○
```

Components:
- Name label (bold, 14px)
- [BALL] tag (shown if `has_ball`, orange)
- Stamina bar (visual, 80px wide, same color logic as token bar)
- Hype bar (visual, 80px wide, gold gradient)
- Actions pips: 3 circles, filled=remaining, empty=spent

```gdscript
func refresh(baller: Node) -> void:
    _name_label.text = baller.stats.display_name
    _ball_tag.visible = baller.has_ball
    _stamina_bar.value = float(baller.current_stamina) / float(baller.stats.max_stamina)
    _hype_bar.value = baller.current_hype / 100.0
    _refresh_action_pips()
    queue_redraw()
```

Bars implemented as `ProgressBar` nodes with custom StyleBoxFlat (no built-in theme).

---

## 20D — `HypeMilestoneFX.gd`

**Location:** `scenes/battle/HypeMilestoneFX.gd`
**Type:** Node2D, child of `_court` (positioned between GridOverlay and TargetOverlay)

### HypeManager changes

Add signal and tracking to `HypeManager.gd`:
```gdscript
signal hype_milestone(level: int)

var _milestone_triggered: Dictionary = {100: false, 200: false, 300: false, 400: false, 500: false}

# In gain_hype(), after updating baller.current_hype:
var total: float = get_team_hype()
for threshold in _milestone_triggered.keys():
    if total >= threshold and not _milestone_triggered[threshold]:
        _milestone_triggered[threshold] = true
        hype_milestone.emit(threshold)
        break
```

Reset `_milestone_triggered` on `BeatManager.possession_ended`.

### Milestone messages

```gdscript
const MILESTONE_TEXT := {
    100: "MOMENTUM!",
    200: "LOCKED IN!",
    300: "ON FIRE!",
    400: "UNSTOPPABLE!",
    500: "MAXIMUM HYPE!",
}
```

### Visual effect

Full-court width horizontal flash band:
```gdscript
var _alpha: float = 0.0
var _text: String = ""
var _flash_color: Color = Color.YELLOW

func trigger(level: int) -> void:
    _text = MILESTONE_TEXT.get(level, "HYPE!")
    _alpha = 0.65
    _flash_color = Color(1.0, 0.8, 0.1)
    var tween := create_tween()
    tween.tween_property(self, "_alpha", 0.0, 0.6).set_ease(Tween.EASE_OUT)
    tween.finished.connect(queue_redraw, CONNECT_ONE_SHOT)
    queue_redraw()

func _draw() -> void:
    if _alpha <= 0.01:
        return
    var court_w: float = GridManager.GRID_COLS * GridManager.CELL_SIZE
    var court_h: float = GridManager.GRID_ROWS * GridManager.CELL_SIZE
    draw_rect(Rect2(0, 0, court_w, court_h),
        Color(_flash_color.r, _flash_color.g, _flash_color.b, _alpha * 0.4))
    # Centered milestone text
    var font_size: int = 28
    draw_string(ThemeDB.fallback_font,
        Vector2(court_w * 0.5 - 80, court_h * 0.5),
        _text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
        Color(1.0, 1.0, 1.0, _alpha))
```

---

## 20E — BattleDemo._refresh_status() update

The old `_status_label` is removed. `_refresh_status()` now calls:

```gdscript
func _refresh_status() -> void:
    var sel: Node = _selected_baller()
    _scoreboard.refresh()
    _active_play_banner.refresh()
    _baller_info_bar.refresh(sel)
    _selection_ring.position = sel.position
    _selection_ring.queue_redraw()
```

The `_log_label` (7-line rolling log) stays — it's the quick-reference event feed. The full log panel comes in Step 22.

---

## Files Changed

| File | Change |
|------|--------|
| `autoloads/HypeManager.gd` | Add `hype_milestone` signal and threshold tracking; reset on possession_ended |
| `scenes/battle/ScoreboardPanel.gd` | New file |
| `scenes/battle/ActivePlayBanner.gd` | New file |
| `scenes/battle/BallerInfoBar.gd` | New file |
| `scenes/battle/HypeMilestoneFX.gd` | New file |
| `scenes/battle/BattleDemo.gd` | Remove `_status_label`; add 4 new panel nodes; update `_refresh_status()`; add `_hype_fx` node; wire `HypeManager.hype_milestone` |

---

## Testing Checklist

- [ ] Scoreboard shows correct score after each basket
- [ ] Beat counter advances correctly each beat
- [ ] Possession arrow flips during defense phase
- [ ] Active play banner appears when play is called
- [ ] Play banner shows correct beat count
- [ ] Play banner flashes green on trigger, red on expire, then hides
- [ ] Baller info bar updates immediately when different baller selected
- [ ] Stamina bar in info bar matches token bar color
- [ ] Hype milestone triggers at 100/200/300/400/500 total hype
- [ ] Milestone flash doesn't re-trigger for the same threshold in one possession
- [ ] Milestone tracking resets on new possession
