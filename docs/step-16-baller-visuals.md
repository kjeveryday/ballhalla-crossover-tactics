# Step 16 — Baller Token Visual Layer

**Depends on:** Step 15 (stamina_changed signal drives redraws)
**Required by:** Step 22 (Tab cycling reads acted_this_beat visual state)

## Goal

Every baller token communicates its full state — stamina, exhaustion, whether they've acted this beat, ball possession, and ISO designation — without the player opening any menu.

---

## 16A — Stamina Mini-Bar

**Files:** `entities/baller/AlliedBaller.gd`, `entities/baller/EnemyBaller.gd`

Drawn in `_draw()` at the bottom of the token:

```gdscript
# Stamina bar
var bar_w: float = GridManager.CELL_SIZE * 0.70
var bar_h: float = 4.0
var bar_x: float = -bar_w * 0.5
var bar_y: float = GridManager.CELL_SIZE * 0.38

var pct: float = float(current_stamina) / float(stats.max_stamina)
var bar_color: Color
if pct > 0.60:
    bar_color = Color(0.20, 0.85, 0.30)   # green
elif pct > 0.30:
    bar_color = Color(0.95, 0.80, 0.10)   # yellow
else:
    bar_color = Color(0.90, 0.20, 0.15)   # red

# Background
draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.15, 0.15, 0.15))
# Fill
draw_rect(Rect2(bar_x, bar_y, bar_w * pct, bar_h), bar_color)
```

---

## 16B — Exhausted Dimming

In `_draw()`, after drawing the token body and bar:

```gdscript
if is_exhausted:
    var half: float = GridManager.CELL_SIZE * 0.4
    draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color(0.0, 0.0, 0.0, 0.55))
    # X mark
    draw_line(Vector2(-half * 0.5, -half * 0.5), Vector2(half * 0.5, half * 0.5),
        Color(0.9, 0.9, 0.9, 0.8), 2.0)
    draw_line(Vector2(half * 0.5, -half * 0.5), Vector2(-half * 0.5, half * 0.5),
        Color(0.9, 0.9, 0.9, 0.8), 2.0)
```

---

## 16C — Acted-This-Beat Indicator

A small corner-fold in the top-right of the token. Drawn only for allied ballers (enemies don't use acted_this_beat visually):

```gdscript
if acted_this_beat:
    var half: float = GridManager.CELL_SIZE * 0.4
    var fold: float = 10.0
    draw_line(Vector2(half - fold, -half), Vector2(half, -half + fold),
        Color(0.5, 0.5, 0.55, 0.9), 2.0)
```

---

## 16D — Ball Carrier Glow Ring

Drawn in `AlliedBaller._draw()` only (enemy never has ball in this system):

```gdscript
if has_ball:
    var pulse: float = (sin(Time.get_ticks_msec() * 0.004) * 0.5 + 0.5)
    var alpha: float = 0.55 + pulse * 0.35
    draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 24,
        Color(1.0, 0.55, 0.0, alpha), 3.0)
```

> The pulse uses `Time.get_ticks_msec()` which requires `queue_redraw()` to be called every frame while the baller has the ball. Connect `set_process(has_ball)` — enable _process when receiving ball, disable when losing it.

---

## 16E — ISO Mode Ring

Drawn in `AlliedBaller._draw()`:

```gdscript
if PlayManager.iso_baller == self:
    draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 24,
        Color(1.0, 0.35, 0.0, 0.85), 2.5)
    # Dashes: draw 8 arcs with gaps
    # Approximated by drawing 8 short arc segments
```

---

## 16F — Triggering queue_redraw()

Each baller connects these signals in `_ready()`:

```gdscript
func _ready() -> void:
    # ... existing code ...
    BeatManager.beat_started.connect(queue_redraw)
    BeatManager.action_committed.connect(func(_a): queue_redraw())
    StaminaSystem.stamina_changed.connect(func(b, _d): if b == self: queue_redraw())
    HypeManager.hype_changed.connect(func(b): if b == self: queue_redraw())
```

Ball carrier glow also needs `_process()` to run while `has_ball`. Add:

```gdscript
func _process(_delta: float) -> void:
    if has_ball:
        queue_redraw()

# In place_on_grid / wherever has_ball changes:
set_process(has_ball)
```

---

## Files Changed

| File | Change |
|------|--------|
| `entities/baller/AlliedBaller.gd` | Extended `_draw()`: stamina bar, exhausted, acted, ball glow, ISO ring; add signal connections in `_ready()`; add `_process()` for pulse |
| `entities/baller/EnemyBaller.gd` | Extended `_draw()`: stamina bar, exhausted |

---

## Testing Checklist

- [ ] Stamina bar visible on all tokens at start
- [ ] Bar color changes green→yellow→red as stamina drains
- [ ] Exhausted baller shows dark overlay + X mark
- [ ] Acted baller shows corner-fold indicator; clears at beat start
- [ ] Ball carrier shows pulsing orange ring
- [ ] ISO mode shows dashed outer ring; disappears when iso_baller is cleared
- [ ] All visuals update immediately after actions without needing a manual refresh
