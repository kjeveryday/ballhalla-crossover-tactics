# Shot Clock Enforcement

## Decision (D3)

The shot clock is **real**, not cosmetic. When the 24-second clock expires, the offense
loses possession — same outcome as a pass turnover.

The 8-beat possession cap (8 × 3s = 24s) and the shot clock expire simultaneously under
current math. The wiring is correct so that if clock duration ever diverges from the beat
limit (e.g., a future reset-on-offensive-rebound rule), enforcement fires automatically.

## Behaviors

| # | Behavior |
|---|----------|
| B1 | `ShotClock` emits `shot_clock_expired` when `time_remaining` reaches 0 |
| B2 | `BeatManager.end_beat()` checks shot clock expiry before advancing the beat counter |
| B3 | If the clock expires with beats remaining, `AbilitySystem._handle_turnover(carrier)` is called on the allied ball carrier |
| B4 | If no allied baller has the ball when the clock expires, `possession_ended` emits directly (defense phase begins) |

## Files Changed

- `autoloads/ShotClock.gd` — added `signal shot_clock_expired()`; emits on zero in `decrement_beat()`
- `autoloads/BeatManager.gd` — violation guard after `ShotClock.decrement_beat()` in `end_beat()`; added `_trigger_shot_clock_violation()`

## Notes

`AbilitySystem._handle_turnover()` handles `has_ball` clearing, `turnover_occurred` emission,
and `QuarterManager.end_possession()`. Shot clock violation reuses this path so the floating
"TURNOVER!" text and log entry fire the same way as a pass turnover.
