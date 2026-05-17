# Baller Token Visual Layer — Implementation Spec

## Source
- Design doc: `docs/step-16-baller-visuals.md`
- Related ARCHITECTURE.md sections: None yet recorded (see Open Questions)
- Date specced: 2026-05-17

## What This Mechanic Does (Design Intent)

Every baller token on the grid must communicate its full tactical state at a glance, without the player opening any menu or hovering over anything. The visual layer gives the player the information they need — stamina remaining, whether a baller is exhausted and unplayable, whether they have already acted this beat, whether they hold the ball, and whether they are in ISO mode — encoded as distinct, non-overlapping visual indicators drawn directly on the token.

The stamina mini-bar anchors the player's resource awareness to each individual token rather than to a sidebar, so attention stays on the grid during fast decision-making. Exhaustion is communicated with an unmissable darkening overlay and an X mark that makes the baller obviously unavailable. The acted-this-beat corner fold is a lightweight signal used by the Tab-cycling system (Step 22) and by the player to instantly identify which allied ballers still have actions remaining in the current beat.

Ball possession and ISO designation are communicated through concentric ring overlays. The ball carrier ring pulses in real time, creating a liveness cue that distinguishes it from static rings. The ISO ring uses a dashed style at a slightly larger radius so both rings can be visible simultaneously without ambiguity.

## Data Schema Changes

- New Resources: None
- Modified Resources: None — all state is read from existing properties (`current_stamina`, `stats.max_stamina`, `is_exhausted`, `acted_this_beat`, `has_ball`) that Step 15 and earlier steps establish
- New constants in GameConstants:
  - `STAMINA_BAR_WIDTH_RATIO: float = 0.70` — stamina bar width as fraction of `CELL_SIZE`
  - `STAMINA_BAR_HEIGHT: float = 4.0` — stamina bar height in pixels
  - `STAMINA_BAR_Y_RATIO: float = 0.38` — stamina bar vertical offset as fraction of `CELL_SIZE`
  - `STAMINA_GREEN_THRESHOLD: float = 0.60` — pct above which bar is green
  - `STAMINA_YELLOW_THRESHOLD: float = 0.30` — pct above which (and at or below green) bar is yellow
  - `EXHAUSTION_OVERLAY_ALPHA: float = 0.55` — black overlay opacity on exhausted token
  - `EXHAUSTION_HALF_RATIO: float = 0.4` — half-size of exhaustion overlay rect as fraction of `CELL_SIZE`
  - `ACTED_FOLD_SIZE: float = 10.0` — pixel length of corner-fold indicator line
  - `BALL_GLOW_RADIUS: float = 34.0` — radius of ball carrier ring in pixels
  - `BALL_PULSE_SPEED: float = 0.004` — multiplier applied to `Time.get_ticks_msec()` for pulse frequency
  - `BALL_GLOW_ALPHA_BASE: float = 0.55` — minimum alpha of ball carrier ring
  - `BALL_GLOW_ALPHA_RANGE: float = 0.35` — alpha added at pulse peak
  - `ISO_RING_RADIUS: float = 36.0` — radius of ISO mode ring in pixels
  - `ISO_RING_DASH_COUNT: int = 8` — number of arc segments in dashed ISO ring

## Behavior Specification

1. When an `AlliedBaller` or `EnemyBaller` token is drawn and `current_stamina / stats.max_stamina > 0.60`, the stamina bar fill must render in green (`Color(0.20, 0.85, 0.30)`) at a width equal to `GridManager.CELL_SIZE * 0.70 * pct`.
2. When `current_stamina / stats.max_stamina` is in the range `(0.30, 0.60]`, the stamina bar fill must render in yellow (`Color(0.95, 0.80, 0.10)`).
3. When `current_stamina / stats.max_stamina <= 0.30`, the stamina bar fill must render in red (`Color(0.90, 0.20, 0.15)`).
4. When `current_stamina == 0`, the stamina bar fill width must equal `0.0` (no fill drawn; background bar is still visible).
5. When `current_stamina == stats.max_stamina`, the stamina bar fill width must equal `GridManager.CELL_SIZE * 0.70` (full width).
6. When `is_exhausted == true` on any baller, a dark rectangle of dimensions `GridManager.CELL_SIZE * 0.8 x GridManager.CELL_SIZE * 0.8` centered on the token must be drawn with alpha `0.55`, covering the token body.
7. When `is_exhausted == true`, two white lines forming an X mark must be drawn inside the exhausted overlay at alpha `0.8`, with each line spanning from `±(half * 0.5)` on both axes.
8. When `is_exhausted == false`, no dark overlay or X mark is drawn.
9. When `acted_this_beat == true` on an `AlliedBaller`, a corner-fold line must be drawn in the top-right corner of the token (from `(half - 10, -half)` to `(half, -half + 10)` where `half = GridManager.CELL_SIZE * 0.4`) in color `Color(0.5, 0.5, 0.55, 0.9)`.
10. When `acted_this_beat == false`, no corner-fold line is drawn.
11. `EnemyBaller` must never draw a corner-fold indicator regardless of any `acted_this_beat` property value.
12. When `has_ball == true` on an `AlliedBaller`, an arc of radius `34.0` pixels centered on `Vector2.ZERO` must be drawn with color `Color(1.0, 0.55, 0.0, alpha)` where `alpha = 0.55 + (sin(Time.get_ticks_msec() * 0.004) * 0.5 + 0.5) * 0.35`; the arc must span the full circle (`0.0` to `TAU`) with 24 points and line width `3.0`.
13. When `has_ball == true`, `set_process(true)` must be active on that `AlliedBaller` so that `_process()` calls `queue_redraw()` every frame, animating the pulse.
14. When `has_ball` transitions to `false`, `set_process(false)` must be called on that baller, stopping per-frame redraws.
15. `EnemyBaller` must never draw a ball carrier glow ring.
16. When `PlayManager.iso_baller == self` on an `AlliedBaller`, a dashed arc of radius `36.0` pixels must be drawn consisting of 8 evenly-spaced arc segments in color `Color(1.0, 0.35, 0.0, 0.85)` with line width `2.5`.
17. When `PlayManager.iso_baller != self` (or is null), no ISO ring is drawn on that baller.
18. `EnemyBaller` must never draw an ISO ring.
19. When `BeatManager.beat_started` fires, all ballers must call `queue_redraw()` within the same frame.
20. When `BeatManager.action_committed` fires (with any payload), all ballers must call `queue_redraw()` within the same frame.
21. When `StaminaSystem.stamina_changed` fires with a baller reference matching `self`, that baller must call `queue_redraw()`.
22. When `HypeManager.hype_changed` fires with a baller reference matching `self`, that baller must call `queue_redraw()`.
23. All four signal connections (beat_started, action_committed, stamina_changed, hype_changed) must be established in `_ready()`.
24. The draw order within `_draw()` must be: token body (existing), stamina bar, exhausted overlay (if applicable), corner-fold (if applicable), ball glow ring (if applicable), ISO ring (if applicable). No visual indicator may occlude another in an unreadable way.
25. The stamina bar background rectangle must always render in `Color(0.15, 0.15, 0.15)` regardless of stamina level, providing a fixed-width track behind the fill.

## Signals

- New signals on GameEvents: None — this spec only adds listeners to existing signals
- New listeners required:
  - `AlliedBaller._ready()` must connect: `BeatManager.beat_started` → `queue_redraw`
  - `AlliedBaller._ready()` must connect: `BeatManager.action_committed` → `func(_a): queue_redraw()`
  - `AlliedBaller._ready()` must connect: `StaminaSystem.stamina_changed` → `func(b, _d): if b == self: queue_redraw()`
  - `AlliedBaller._ready()` must connect: `HypeManager.hype_changed` → `func(b): if b == self: queue_redraw()`
  - `EnemyBaller._ready()` must connect the same four signals with identical guard logic

## Edge Cases and Failure Modes

- **Baller with `stats.max_stamina == 0`:** Division by zero when computing `pct`. The stamina bar draw code must guard with `if stats.max_stamina > 0` before computing `pct`; if `max_stamina` is zero, skip the fill draw entirely (draw only the background track).
- **Baller that has `has_ball == true` and `PlayManager.iso_baller == self` simultaneously:** Both the ball glow ring (radius 34, alpha-pulsed, width 3) and the ISO ring (radius 36, dashed, width 2.5) must be drawn concurrently. The 2-pixel radius gap is the only spatial separation. Neither ring must be skipped. The draw order must place the ISO ring after the ball glow so it renders on top.
- **`acted_this_beat` is never reset between beats:** If `BeatManager.beat_started` does not clear `acted_this_beat` before the redraw signal fires, the corner-fold will incorrectly persist. This spec requires that the signal handler's redraw reads the current value of `acted_this_beat` — it does not reset the flag itself. The correct fix lives in the beat state reset logic (Step 15 scope), not here.
- **Baller is freed mid-frame while `has_ball == true` and `_process()` is active:** Godot will automatically stop processing a freed node, but if the signal connection to `stamina_changed` or others is not disconnected, a dangling callable may fire. Signal lambdas must reference `self` only within a `if is_instance_valid(self)` guard, or connections must use `CONNECT_ONE_SHOT` / disconnection in `_exit_tree()`.
- **`PlayManager.iso_baller` is null at draw time:** The ISO ring condition `PlayManager.iso_baller == self` will evaluate to false when `iso_baller` is null (comparing null to a Node reference), so no ring is drawn. No null check is strictly required for correctness, but the implementation must not call any method on `PlayManager.iso_baller` in this condition without a null guard.
- **Stamina bar drawn at exactly threshold boundary (pct == 0.60 or pct == 0.30):** The thresholds are exclusive on the upper bound (`pct > 0.60` is green, `pct > 0.30` is yellow, else red). At `pct == 0.60` the bar must be yellow, not green. At `pct == 0.30` the bar must be red, not yellow. Tests must assert these boundary values explicitly.

## Out of Scope

- **Tooltip or menu display of stamina numbers** — this spec covers only the mini-bar visual; no numeric readout is specified here.
- **Animation on stamina bar change** — the bar snaps to the new value immediately on redraw; no tween or interpolation is specified.
- **Sound effects tied to visual state changes** — audio cues for exhaustion, ball acquisition, or ISO activation are not part of this visual layer spec.
- **Enemy ball possession visuals** — the design doc explicitly states enemies never carry the ball in this system; an enemy ball glow ring is not specced.
- **Enemy ISO ring** — ISO designation is an allied mechanic only; no enemy ISO visual exists.
- **Enemy acted-this-beat indicator** — the design doc explicitly excludes enemies from the corner-fold indicator.
- **Accessibility / colorblind alternatives** — alternate color schemes or shape-only modes are not addressed here.
- **Beat-end cleanup of `acted_this_beat`** — resetting the flag itself is Step 15 scope; this spec only reads the flag's current value.
- **Hype bar visual** — `HypeManager.hype_changed` triggers a redraw here, but the hype bar itself (if any) is a separate mechanic and is not drawn by this spec.
- **Token body and sprite rendering** — the existing token body draw logic is not modified; this spec only adds indicators drawn after the body.

## Open Questions for Human

1. **ISO ring dash implementation:** The design doc notes "draw 8 short arc segments" as an approximation of a dashed ring but does not specify the exact arc span per segment or gap size. Should each of the 8 segments span `TAU / 16` (half of an even division) with equal gaps, or is a different ratio preferred for readability?
2. **Ball glow ring on ISO baller:** When a baller is simultaneously the ball carrier and the ISO baller, both rings are drawn (radii 34 and 36). Is the 2-pixel gap visually sufficient to distinguish them, or should the radii be adjusted to increase separation?
3. **`_process` scope:** The design doc specifies `set_process(has_ball)` as the mechanism to enable per-frame redraws for the pulse. Should `_process` be used exclusively for this purpose, or may other per-frame work be added to `AlliedBaller._process()` in future steps without spec amendment?
4. **HypeManager signal payload:** The spec lists `HypeManager.hype_changed` as firing with a baller reference as its first argument (`func(b): if b == self`). Please confirm the actual signal signature of `HypeManager.hype_changed` — if the payload differs, the lambda guard in `_ready()` must be updated.
5. **Draw layer / z-index:** All visual indicators are drawn via `_draw()` on the baller node itself. If ballers overlap on the grid (stacked on the same cell), should any z-ordering be applied to ensure the active/ISO baller renders on top, or is overlapping assumed to be impossible by grid rules?
