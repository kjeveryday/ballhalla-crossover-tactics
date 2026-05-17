# floating_text — Implementation Spec

## Source
- Design doc: `docs/step-15-floating-text.md`
- Related ARCHITECTURE.md sections: None (ARCHITECTURE.md is currently empty)
- Date specced: 2026-05-17

---

## What This Mechanic Does (Design Intent)

Every meaningful game event in Ballhalla now surfaces visually at the point where it happens. When a baller drains stamina, uses an ability, scores a basket, or gains hype, a small text label rises from that baller's position and fades out — giving the player immediate, spatially grounded feedback without requiring them to scan a HUD. The player understands what happened and why their resources changed without breaking flow.

This system is purely cosmetic and additive: it never changes game state. Its purpose is to close the gap between what the engine knows and what the player perceives. Before this step, scoring two points and losing ten stamina were invisible except as stat changes; after it, those events announce themselves in the court space and disappear without cluttering the screen.

The `stamina_changed` signal added in 15A is the connective tissue that makes this possible: rather than every consumer of stamina needing to spawn its own feedback, a single signal allows `FloatingTextSpawner` to be the one subscriber that handles all visual responses, keeping feedback logic out of game-logic systems.

---

## Data Schema Changes

- New Resources: none
- Modified Resources: none
- New constants in GameConstants:
  - `FLOATING_TEXT_RISE_PX: int = 40` — vertical travel distance in pixels
  - `FLOATING_TEXT_DURATION_SEC: float = 0.7` — total animation duration in seconds
  - `FLOATING_TEXT_SIZE_LARGE: int = 22` — font size for score events
  - `FLOATING_TEXT_SIZE_MEDIUM: int = 16` — font size for miss and generic events
  - `FLOATING_TEXT_SIZE_SMALL: int = 13` — font size for stamina and hype events
  - `FLOATING_TEXT_GENERIC_EVENT_SIZE: int = 15` — font size for named game events (REBOUND, TURNOVER, etc.)

---

## Behavior Specification

### 15A — StaminaSystem.stamina_changed Signal

1. When `StaminaSystem` resolves an action cost and calls `baller.drain_stamina(cost)`, it must emit `stamina_changed(baller, -cost)` immediately after the drain completes.
2. When `StaminaSystem.apply_idle_recovery()` calls `baller.heal_stamina(IDLE_RECOVERY)`, it must emit `stamina_changed(baller, IDLE_RECOVERY)` immediately after the heal completes.
3. `stamina_changed` must carry a negative `delta` for drains and a positive `delta` for heals; the sign must be consistent so downstream listeners can determine direction from `delta` alone.
4. No other system (Baller, AbilitySystem, ShotSystem, EnemyAI) may emit `stamina_changed` directly — all stamina signal traffic routes through StaminaSystem.

### 15B — FloatingText Node

5. `FloatingText.spawn(parent, world_pos, text, color, font_size)` must add a new `FloatingText` node as a direct child of `parent` at position `world_pos`.
6. The spawned node must contain a `Label` child displaying `text` in `color` at `font_size`.
7. Upon spawning, a Tween must begin that moves the node's Y position up by `FLOATING_TEXT_RISE_PX` pixels over `FLOATING_TEXT_DURATION_SEC` seconds using an ease-out curve.
8. The same Tween must simultaneously animate the Label's alpha (modulate.a) from 1.0 to 0.0 over `FLOATING_TEXT_DURATION_SEC` seconds.
9. When the Tween finishes, the FloatingText node must call `queue_free()` on itself; no manual cleanup is required by the caller.
10. `FloatingText.spawn` is a static method; callers must never instantiate `FloatingText` directly via `new()` or `instantiate()`.

### 15C — FloatingTextSpawner Typed Methods

11. `spawn_score(pos, points)` must produce a label displaying `"+" + str(points)` at font size `FLOATING_TEXT_SIZE_LARGE` (22px) in white (Color.WHITE).
12. `spawn_miss(pos)` must produce a label displaying `"MISS"` at font size `FLOATING_TEXT_SIZE_MEDIUM` (16px) in red (Color.RED).
13. `spawn_stamina(pos, delta)` must produce a label displaying `str(delta) + " STM"` (e.g., `"-10 STM"` or `"+8 STM"`) at font size `FLOATING_TEXT_SIZE_SMALL` (13px); the color must be Color.RED when `delta < 0` and Color.GREEN when `delta > 0`.
14. `spawn_hype(pos, delta)` must produce a label displaying `str(delta) + " HYPE"` (e.g., `"+10 HYPE"`) at font size `FLOATING_TEXT_SIZE_SMALL` (13px) in gold (Color(1.0, 0.84, 0.0, 1.0)).
15. `spawn_event(pos, text)` must produce a label displaying `text` verbatim at font size `FLOATING_TEXT_GENERIC_EVENT_SIZE` (15px) in white (Color.WHITE).
16. All five typed methods must pass the spawner's parent node (`_court`) as the `parent` argument to `FloatingText.spawn`, so all floating texts share court-space coordinates.

### Signal Wiring

17. When `ShotSystem.shot_made(shooter, points)` fires, `FloatingTextSpawner` must call `spawn_score(shooter.position, points)`.
18. When `ShotSystem.shot_missed(shooter)` fires, `FloatingTextSpawner` must call `spawn_miss(shooter.position)`.
19. When `StaminaSystem.stamina_changed(baller, delta)` fires, `FloatingTextSpawner` must call `spawn_stamina(baller.position, delta)`.
20. When `HypeManager.hype_changed` fires with a computable delta, `FloatingTextSpawner` must call `spawn_hype(baller.position, delta)`.
21. When `ShotSystem.rebound_won(baller, _)` fires and `baller` is not null, `FloatingTextSpawner` must call `spawn_event(baller.position, "REBOUND")`.
22. All signal connections must be established before the first game beat resolves; connections must survive scene reloads without duplication.

---

## Signals

- **New signal on StaminaSystem:** `stamina_changed(baller: Node, delta: int)`
  - Payload: the baller whose stamina changed, and the signed integer delta (negative = drain, positive = heal)
- **Modified signal on HypeManager:** `hype_changed(baller: Node, delta: float)` — `delta: float` parameter added
  - If adding a parameter to `hype_changed` breaks existing listeners, the alternative is for `FloatingTextSpawner` to maintain a `Dictionary` of previous hype values keyed by baller and compute delta on receipt. The spec leaves this choice open (see Open Questions).
- **New listener required:** `FloatingTextSpawner` must connect to:
  - `StaminaSystem.stamina_changed`
  - `HypeManager.hype_changed`
  - `ShotSystem.shot_made`
  - `ShotSystem.shot_missed`
  - `ShotSystem.rebound_won`
  - `AbilitySystem.turnover_occurred` (wired in Step 22 — connection point must be reserved here)

---

## Edge Cases and Failure Modes

- **What if `delta` is zero for stamina or hype?** A delta of zero must not spawn a floating text; `spawn_stamina` and `spawn_hype` must guard with `if delta == 0: return` before calling `FloatingText.spawn`. A zero delta provides no information to the player.
- **What if multiple ballers drain stamina on the same beat?** Each `stamina_changed` emission is independent, so each baller gets its own floating text at its own position. Texts spawned at the same world position must stack (they are separate nodes); they are not deduplicated.
- **What if `baller` is null in a signal payload?** `FloatingTextSpawner` must guard every signal handler with `if baller == null: return` before reading `baller.position`. This prevents crashes during edge cases such as a baller being freed between signal emission and handler execution.
- **What if `FloatingText.spawn` is called after `_court` has been freed (e.g., mid-scene transition)?** The `parent` argument will be an invalid object. `FloatingText.spawn` must check `is_instance_valid(parent)` and return without spawning if false.
- **What if a baller scores and immediately queue_frees (e.g., on death)?** The FloatingText is a child of `_court`, not the baller, so it will continue its animation and free itself normally regardless of the shooter's lifetime.
- **What if many simultaneous events fire (e.g., AoE trash talk hits all four enemies at once)?** Four separate floating texts spawn at four different positions. No deduplication or batching is applied. If all four share the same position (edge case), the texts overlap. This is acceptable for now and noted as a known visual artifact.

---

## Out of Scope

- Floating text triggered by `AbilitySystem.turnover_occurred` — this signal does not exist until Step 22; the connection point is reserved but not wired.
- Score text color animation (white → gold gradient during the tween) — the design doc mentions it but it requires a shader or multi-step tween not specified here; deferred to a future polish pass.
- Floating text for block events, steal events, or any events not explicitly listed in the signal wiring table.
- Sound effects synchronized to floating text appearance.
- HUD or overlay text (positioned in screen-space rather than court-space).
- Pooling or recycling of FloatingText nodes for performance — each spawn allocates a new node.
- Configurable easing curves beyond ease-out — the curve is fixed.

---

## Open Questions for Human

1. **HypeManager delta approach:** Should `hype_changed` gain a `delta: float` parameter (cleaner, but breaks any existing listeners), or should `FloatingTextSpawner` maintain a previous-hype dictionary and compute delta locally (no signal breakage, but spawner carries more state)? The design doc mentions both options without choosing.
2. **Score color transition:** The design doc specifies "bright white → fades to gold" for `spawn_score`. Is this a priority for Step 15, or is a flat white acceptable until a dedicated visual polish pass?
3. **Stamina positive delta distinction:** Idle recovery emits `stamina_changed` with a positive delta. Should `spawn_stamina` display `"+8 STM"` in green for recovery, or should recovery use a distinct label (e.g., `"+8 REC"` or a blue color) to distinguish healing from cost events? The design doc uses green for any positive delta.
