# Step 17 — Animation System

**Depends on:** Steps 15–16
**Required by:** Step 21 (TransitionScreen waits on _is_animating)

## Goal

Ballers visually move tile-to-tile, passes show ball travel, shots have a visible arc. All input is blocked during animations. Grid state remains authoritative and updates instantly — only the visual representation is delayed.

---

## Core Rule: Grid State vs Visual State

`baller.grid_col` / `baller.grid_row` are always updated instantly by `MovementSystem`.
`baller.position` (the Node2D world position) is what gets tweened.
BeatManager never awaits anything. It finishes synchronously. BattleDemo then plays the animation as a visual-only followup.

---

## 17A — `_is_animating` Flag in BattleDemo

```gdscript
var _is_animating: bool = false
var _pending_transition: Callable = Callable()
```

`BattleDemo._input()` returns early at the top if `_is_animating`, except:
- ESC → snap all tweens to their end values and set `_is_animating = false`

When `_is_animating` transitions from `true` → `false`, check `_pending_transition`:
```gdscript
func _finish_animation() -> void:
    _is_animating = false
    if _pending_transition.is_valid():
        _pending_transition.call()
        _pending_transition = Callable()
```

This allows Step 21's TransitionScreen to queue itself for "show after animations finish."

---

## 17B — Movement Tween

### Signal: `MovementSystem.baller_moved(baller, world_pos)`

Add to `MovementSystem.gd`:
```gdscript
signal baller_moved(baller: Node, world_pos: Vector2)
```

In `continue_movement()`, after `baller.place_on_grid(next.x, next.y)`, emit:
```gdscript
baller_moved.emit(baller, GridManager.grid_to_world(next.x, next.y))
```

Note: `place_on_grid()` currently sets `baller.position` directly. Change it to only update `grid_col`/`grid_row`, not `.position`. The tween in BattleDemo drives `.position`. On `_ready()`, ballers set their initial `.position` normally.

### BattleDemo wiring

```gdscript
# In _wire_signals():
MovementSystem.baller_moved.connect(_on_baller_moved)

func _on_baller_moved(baller: Node, target_pos: Vector2) -> void:
    _is_animating = true
    var tween := create_tween()
    tween.tween_property(baller, "position", target_pos, 0.22)\
         .set_ease(Tween.EASE_IN_OUT)\
         .set_trans(Tween.TRANS_CUBIC)
    tween.finished.connect(_finish_animation, CONNECT_ONE_SHOT)
```

If multiple ballers move in the same beat-end sequence (e.g., 1 allied in-motion + 5 enemies), all their tweens start simultaneously. `_is_animating` is set true once and cleared when the longest tween finishes. Track with a counter:

```gdscript
var _anim_count: int = 0

func _on_baller_moved(baller: Node, target_pos: Vector2) -> void:
    _is_animating = true
    _anim_count += 1
    var tween := create_tween()
    tween.tween_property(baller, "position", target_pos, 0.22)
    tween.finished.connect(_on_single_anim_done, CONNECT_ONE_SHOT)

func _on_single_anim_done() -> void:
    _anim_count -= 1
    if _anim_count <= 0:
        _finish_animation()
```

---

## 17C — Pass Animation

### Signal: `AbilitySystem.pass_completed(from_pos, to_pos)`

Add to `AbilitySystem.gd` in `attempt_pass()` on success:
```gdscript
signal pass_completed(from_pos: Vector2, to_pos: Vector2)

# In attempt_pass(), after to_baller.has_ball = true:
pass_completed.emit(from_baller.position, to_baller.position)
```

### `BallIndicator.gd` changes

Add a `tween_to(target_pos: Vector2, duration: float)` method:
```gdscript
var _override_position: bool = false

func tween_to(target_pos: Vector2, duration: float) -> void:
    _override_position = true
    var tween := create_tween()
    # Arc the ball: tween X linearly, tween Y through a midpoint
    # Use a parabolic path via two chained tweens or a custom method
    tween.tween_property(self, "position", target_pos + Vector2(0, -20), duration * 0.5)
    tween.tween_property(self, "position", target_pos + Vector2(0, -28), duration * 0.5)
    tween.finished.connect(func(): _override_position = false, CONNECT_ONE_SHOT)

func _process(_delta: float) -> void:
    if _override_position:
        return  # tween is driving position
    var carrier: Node = AlliedTeam.get_ball_carrier()
    # ... existing logic ...
```

### BattleDemo wiring

```gdscript
# In _wire_signals():
AbilitySystem.pass_completed.connect(_on_pass_completed)

func _on_pass_completed(from_pos: Vector2, to_pos: Vector2) -> void:
    _is_animating = true
    _anim_count += 1
    _ball_indicator.tween_to(to_pos + Vector2(0, -28), 0.30)
    # Ball indicator signals done via its tween — connect to _on_single_anim_done
```

---

## 17D — Shot Arc Overlay

**Location:** `scenes/battle/ShotArcOverlay.gd`
**Type:** Node2D, child of `_court`

```gdscript
extends Node2D

var _shooter_pos: Vector2 = Vector2.ZERO
var _active: bool = false

func show_arc(shooter_pos: Vector2) -> void:
    _shooter_pos = shooter_pos
    _active = true
    queue_redraw()

func hide_arc() -> void:
    _active = false
    queue_redraw()

func _draw() -> void:
    if not _active:
        return
    # Rim is at row 0, same col as shooter
    var rim_pos: Vector2 = GridManager.grid_to_world(
        int(_shooter_pos.y / GridManager.CELL_SIZE),  # approximate col
        0
    )
    # Draw 16 dots along a parabolic arc
    var peak: Vector2 = (_shooter_pos + rim_pos) * 0.5 + Vector2(0, -96)
    for i in range(17):
        var t: float = float(i) / 16.0
        var pt: Vector2 = _quadratic_bezier(_shooter_pos, peak, rim_pos, t)
        draw_circle(pt, 3.0, Color(1.0, 0.9, 0.4, 0.8 - t * 0.4))

func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
    var mt: float = 1.0 - t
    return mt * mt * p0 + 2.0 * mt * t * p1 + t * t * p2
```

### BattleDemo wiring

```gdscript
# In _build_scene(), add before TargetOverlay:
_shot_arc = Node2D.new()
_shot_arc.set_script(load("res://scenes/battle/ShotArcOverlay.gd"))
_court.add_child(_shot_arc)

# In AbilitySystem.attempt_shot(), before ShotSystem.attempt_shot(shooter):
# BattleDemo pre-arms the arc via a signal or direct call

# In _wire_signals():
ShotSystem.shot_made.connect(func(_s, _p): _shot_arc.hide_arc())
ShotSystem.shot_missed.connect(func(_s): _shot_arc.hide_arc())

# In _on_action_chosen("shoot"):
_shot_arc.show_arc(_selected_baller().position)
AbilitySystem.attempt_shot(sel)
```

---

## Files Changed

| File | Change |
|------|--------|
| `autoloads/MovementSystem.gd` | Add `baller_moved` signal; decouple `.position` from `place_on_grid()` |
| `autoloads/AbilitySystem.gd` | Add `pass_completed` signal |
| `entities/baller/Baller.gd` | `place_on_grid()` updates grid coords only; initial position set via `GridManager.grid_to_world()` in `_ready()` |
| `scenes/battle/BallIndicator.gd` | Add `tween_to()`, `_override_position` flag |
| `scenes/battle/ShotArcOverlay.gd` | New file |
| `scenes/battle/BattleDemo.gd` | Add `_is_animating`, `_anim_count`, `_pending_transition`; wire movement/pass/shot signals; add `_shot_arc` node |

---

## Testing Checklist

- [ ] Move action: baller slides smoothly to destination over ~0.22s
- [ ] Multiple enemy moves at beat end all animate simultaneously
- [ ] Pass: ball indicator tweens from passer to receiver
- [ ] Shoot: dotted arc appears from shooter toward rim, disappears on result
- [ ] All input blocked during animations
- [ ] ESC during animation snaps to end state cleanly
- [ ] No input events are swallowed after `_is_animating` clears
