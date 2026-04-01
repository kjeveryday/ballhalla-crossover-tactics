# Step 15 — Foundation: Floating Text + Stamina Signal

**Depends on:** Steps 1–14 (core systems)
**Required by:** Steps 16, 17, 18, 21, 22

## Goal

Establish two foundational systems that every other polish step depends on:
1. A `stamina_changed` signal so stamina events can drive visuals.
2. A `FloatingText` system that surfaces all game events to the player's eyes.

---

## 15A — `StaminaSystem.stamina_changed(baller, delta)` Signal

### Change: `StaminaSystem.gd`

Add signal declaration:
```gdscript
signal stamina_changed(baller: Node, delta: int)
```

Emit it from two places:
- After `baller.drain_stamina(cost)` calls in `get_stamina_cost()` resolution — wrap drain in a helper that emits: `stamina_changed.emit(baller, -cost)`
- After `baller.heal_stamina(IDLE_RECOVERY)` in `apply_idle_recovery()` — emit: `stamina_changed.emit(baller, IDLE_RECOVERY)`

> Note: `Baller.drain_stamina()` and `Baller.heal_stamina()` are called from multiple systems (AbilitySystem, ShotSystem, EnemyAI). Rather than emitting from Baller directly (which would require Baller to depend on StaminaSystem), emit from the callers via StaminaSystem helper methods or just emit from the two sites above. The key requirement is that downstream systems only need to connect one signal.

---

## 15B — `FloatingText.gd`

**Location:** `scenes/battle/FloatingText.gd`
**Type:** Node2D

A self-destructing node that animates a text label upward and fades out.

### Constructor pattern
```gdscript
static func spawn(parent: Node, world_pos: Vector2, text: String,
                  color: Color, font_size: int = 16) -> void
```
- Creates a new `FloatingText` instance
- Adds it as a child of `parent` at `world_pos`
- Creates a `Label` child with the given text/color/size
- Runs a Tween: Y position moves up 40px over 0.7s (ease OUT), alpha fades 1.0→0.0 over 0.7s
- On tween finish: `queue_free()`

Parent is always the `_court` Node2D so coordinates are in court-space.

---

## 15C — `FloatingTextSpawner.gd`

**Location:** `scenes/battle/FloatingTextSpawner.gd`
**Type:** Node2D (child of `_court` in BattleDemo)

Central dispatcher with typed spawn methods. All methods take `world_pos: Vector2`.

```gdscript
func spawn_score(pos: Vector2, points: int) -> void
    # Large (22px), bright white → fades to gold. "+2" or "+3"

func spawn_miss(pos: Vector2) -> void
    # Medium (16px), red. "MISS"

func spawn_stamina(pos: Vector2, delta: int) -> void
    # Small (13px). Red if delta < 0 ("-10 STM"), green if delta > 0 ("+8 STM")

func spawn_hype(pos: Vector2, delta: float) -> void
    # Small (13px), gold. "+10 HYPE" or "-10 HYPE"

func spawn_event(pos: Vector2, text: String) -> void
    # Medium (15px), white. Used for: TURNOVER, REBOUND, SCREEN, PLAY!, etc.
```

### Signal wiring (in BattleDemo._wire_signals or FloatingTextSpawner._ready)

| Signal | Spawner call |
|--------|-------------|
| `HypeManager.hype_changed(baller)` | `spawn_hype(baller.position, delta)` — delta computed from before/after |
| `StaminaSystem.stamina_changed(baller, delta)` | `spawn_stamina(baller.position, delta)` |
| `ShotSystem.shot_made(shooter, points)` | `spawn_score(shooter.position, points)` |
| `ShotSystem.shot_missed(shooter)` | `spawn_miss(shooter.position)` |
| `ShotSystem.rebound_won(baller, _)` | `spawn_event(baller.position, "REBOUND")` if baller != null |
| `AbilitySystem.turnover_occurred(baller)` | `spawn_event(baller.position, "TURNOVER!")` (signal added in Step 22) |

> **Hype delta tracking:** `HypeManager.hype_changed` doesn't currently pass delta. Either add `delta: float` to the signal, or have FloatingTextSpawner store previous hype values and compute delta on receipt.

---

## Files Changed

| File | Change |
|------|--------|
| `autoloads/StaminaSystem.gd` | Add `stamina_changed` signal, emit after drain/heal |
| `autoloads/HypeManager.gd` | Add `delta` param to `hype_changed` signal (or add separate approach) |
| `scenes/battle/FloatingText.gd` | New file |
| `scenes/battle/FloatingTextSpawner.gd` | New file |
| `scenes/battle/BattleDemo.gd` | Instantiate FloatingTextSpawner as child of `_court`; wire signals |

---

## Testing Checklist

- [ ] Shoot and make → "+2" floats up from shooter position
- [ ] Shoot and miss → "MISS" floats up in red
- [ ] Trash talk → "-10 STM" appears on each affected enemy
- [ ] Leadership → "+10 HYPE" appears on target ally
- [ ] Idle recovery at beat end → "+8 STM" on idle ballers
- [ ] Multiple simultaneous floats don't overlap unreadably
