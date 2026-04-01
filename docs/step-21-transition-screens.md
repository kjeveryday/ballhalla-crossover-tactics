# Step 21 — Transition Screens + Defense Phase Visibility

**Depends on:** Steps 15–20
**Required by:** Step 22 (Turnover fix routes through continuation architecture)

## Goal

Every game state transition the player didn't cause is shown on screen with a clear summary. The player dismisses each screen manually. The defense phase resolves visibly rather than silently.

---

## 21A — QuarterManager Architecture Change

### Core concept: `_continuation: Callable`

QuarterManager currently calls `BeatManager.start_possession()` or `end_quarter()` immediately after events. Every pause-worthy event is now split:

1. Compute the result.
2. Emit an informational signal with the result data.
3. Store the next step as `_continuation`.
4. Stop — wait for BattleDemo to call `QuarterManager.continue_flow()`.

```gdscript
# In QuarterManager.gd:
var _continuation: Callable = Callable()

func continue_flow() -> void:
    if _continuation.is_valid():
        var c := _continuation
        _continuation = Callable()
        c.call()
```

### New signals

```gdscript
signal defense_resolved(scored: bool, points: int,
    enemy_offense: float, allied_defense: float, stamina_factor: float)

signal quarter_break_ready(quarter: int, allied: int, enemy: int)

signal halftime_ready(allied: int, enemy: int)
```

`quarter_ended` already exists — keep it. The new `quarter_break_ready` fires instead of immediately starting the next possession.

### Changed methods

**`_resolve_defense_phase()`** — split into compute + emit:

```gdscript
func _resolve_defense_phase() -> void:
    var enemy_offense: float = EnemyTeam.get_combined_offensive_rating()
    var allied_defense: float = AlliedTeam.get_combined_defensive_rating()
    var stamina_factor: float = AlliedTeam.get_avg_stamina_pct()
    var threshold: float = clamp(
        (enemy_offense - allied_defense * stamina_factor) / 100.0, 0.1, 0.9)

    var scored: bool = randf() < threshold
    var points: int = 0
    if scored:
        points = 3 if randf() > 0.7 else 2
        enemy_score += points
        score_changed.emit(allied_score, enemy_score)

    # Store continuation — after player dismisses defense screen, call end_possession() continuation
    _continuation = func(): _after_defense_screen()
    defense_resolved.emit(scored, points, enemy_offense, allied_defense, stamina_factor)

func _after_defense_screen() -> void:
    end_possession()
```

**`end_quarter()`** — emit break signal instead of immediately continuing:

```gdscript
func end_quarter() -> void:
    _is_defense_phase = false
    quarter_ended.emit(current_quarter)

    if current_quarter >= 4:
        _check_overtime()
    elif current_quarter == 2:
        current_quarter += 1
        GameStateMachine.transition_to(GameStateMachine.BattleState.HALFTIME)
        _continuation = func():
            GameStateMachine.transition_to(GameStateMachine.BattleState.OFFENSE_START)
            BeatManager.start_possession()
        halftime_ready.emit(allied_score, enemy_score)
    else:
        current_quarter += 1
        GameStateMachine.transition_to(GameStateMachine.BattleState.QUARTER_END)
        _continuation = func():
            GameStateMachine.transition_to(GameStateMachine.BattleState.OFFENSE_START)
            BeatManager.start_possession()
        quarter_break_ready.emit(current_quarter - 1, allied_score, enemy_score)
```

### Halftime choice methods

```gdscript
func apply_halftime_choice(choice: String) -> void:
    match choice:
        "rest_team":
            for b in AlliedTeam.get_active_ballers():
                b.current_stamina = b.stats.max_stamina
                b.is_exhausted = false
        "call_play":
            # Pre-load Pick & Roll without spending an action
            PlayManager.active_play = PlayManager.PLAYBOOK["pick_and_roll"]
            PlayManager.sequence_progress.clear()
            PlayManager.play_called.emit("Pick and Roll (Halftime Adjustment)")
    continue_flow()
```

---

## 21B — `TransitionScreen.gd`

**Location:** `scenes/battle/TransitionScreen.gd`
**Type:** Control, child of HUD CanvasLayer (added last, so it's on top of everything)

### Public API

```gdscript
func show_defense_result(scored: bool, points: int,
        enemy_offense: float, allied_defense: float, stamina_factor: float) -> void

func show_quarter_end(quarter: int, allied: int, enemy: int,
        stats: Dictionary) -> void

func show_halftime(allied: int, enemy: int) -> void
```

Each show_* method populates the content area, enables `mouse_filter = STOP`, and makes the screen visible.

### Layout structure

```
┌─────────────────────────────────────────┐
│                                         │
│         [Title — large, centered]       │
│                                         │
│         [Content — varies by mode]      │
│                                         │
│              [ Continue ]               │
│                                         │
└─────────────────────────────────────────┘
```

Background: `Color(0.04, 0.04, 0.08, 0.88)` full-screen rect.
Content panel: centered 480×340px rounded panel (same StyleBoxFlat style).

### Mode: DEFENSE_PHASE

Title: "DEFENSE PHASE" (gray)
Content:
```
Enemy Offense:    342
Allied Defense:   287  (×74% stamina)
─────────────────────
Score chance:      62%
─────────────────────
  ENEMY SCORES 2!     or     ALLIED HOLDS!
```
"Enemy scores" line is red. "Allied holds" is green.

### Mode: QUARTER_END

Title: "END OF QUARTER {n}" (white)
Content: Score banner + per-baller stat table:
```
  Allied 10 — Enemy 8
  ─────────────────────────────────────
  Remix PG     3 pts   2 ast   1 scr
  Remix SG     2 pts   0 ast   0 scr
  Remix SF     0 pts   1 ast   1 scr
  Remix PF     2 pts   0 ast   0 scr
  Remix C      3 pts   1 ast   0 scr
```

Stats come from `_possession_stats` dictionary in BattleDemo (see below).

### Mode: HALFTIME

Title: "HALFTIME" (gold)
Content: Score banner + two strategy buttons:

```
  Allied 10 — Enemy 8
  ─────────────────────────────────────
  Choose a halftime adjustment:

  [ REST TEAM ]            [ CALL THE PLAY ]
  All ballers recover      Pick & Roll activates
  full stamina             automatically next possession
```

Two buttons styled like ActionMenu buttons. Clicking either calls `QuarterManager.apply_halftime_choice(choice)` which also calls `continue_flow()`. No separate Continue button in halftime mode — the choice IS the continue.

### Dismiss in non-halftime modes

Continue button calls `QuarterManager.continue_flow()` then hides the screen.

---

## 21C — Per-Baller Stats Tracking in BattleDemo

```gdscript
var _possession_stats: Dictionary = {}
# Structure: { display_name: { pts, ast, scr, hype_gained } }

func _reset_possession_stats() -> void:
    _possession_stats.clear()
    for b in _ballers:
        _possession_stats[b.stats.display_name] = {pts=0, ast=0, scr=0, hype_gained=0}
```

Incremented from signals already connected in `_wire_signals()`:
- `shot_made` → `_possession_stats[shooter.display_name].pts += points`
- `pass_completed` → `_possession_stats[passer.display_name].ast += 1`
- `screen performed` (new signal from AbilitySystem) → `.scr += 1`
- `hype_changed` → `.hype_gained += delta` (if delta > 0)

Reset at `beat_started` when `beat_num == 1`.

---

## 21D — BattleDemo integration

```gdscript
# New signals to wire:
QuarterManager.defense_resolved.connect(_on_defense_resolved)
QuarterManager.quarter_break_ready.connect(_on_quarter_break_ready)
QuarterManager.halftime_ready.connect(_on_halftime_ready)

func _on_defense_resolved(scored, points, eo, ad, sf) -> void:
    _close_all_panels()
    if _is_animating:
        _pending_transition = func(): _show_defense_screen(scored, points, eo, ad, sf)
    else:
        _show_defense_screen(scored, points, eo, ad, sf)

func _show_defense_screen(scored, points, eo, ad, sf) -> void:
    _transition_screen.show_defense_result(scored, points, eo, ad, sf)

func _on_quarter_break_ready(quarter, allied, enemy) -> void:
    _close_all_panels()
    _transition_screen.show_quarter_end(quarter, allied, enemy, _possession_stats)

func _on_halftime_ready(allied, enemy) -> void:
    _close_all_panels()
    _transition_screen.show_halftime(allied, enemy)

func _close_all_panels() -> void:
    _action_menu.hide_menu()
    _enemy_info_panel.hide_panel()
    _target_overlay.clear()
    _set_ui_state(UIState.IDLE)
```

---

## Files Changed

| File | Change |
|------|--------|
| `autoloads/QuarterManager.gd` | Add `_continuation`, `continue_flow()`, `apply_halftime_choice()`; split `_resolve_defense_phase()` and `end_quarter()` to emit-then-wait pattern; add 3 new signals |
| `autoloads/AbilitySystem.gd` | Add `screen_performed` signal |
| `scenes/battle/TransitionScreen.gd` | New file |
| `scenes/battle/BattleDemo.gd` | Add `_transition_screen` node; add `_possession_stats` tracking; wire 3 new QuarterManager signals; add `_close_all_panels()` |

---

## Testing Checklist

- [ ] Defense phase shows calculation screen before continuing
- [ ] "Allied holds!" and "Enemy scores X!" both shown correctly
- [ ] Continue button resumes game flow
- [ ] Quarter end shows correct stats for each baller
- [ ] Stats accumulated correctly across the possession
- [ ] Halftime screen shows both strategy buttons
- [ ] REST TEAM: all baller stamina restored to max after dismissal
- [ ] CALL THE PLAY: Pick & Roll active banner shows next possession
- [ ] No double-starts: BeatManager.start_possession() never called before Continue pressed
- [ ] Animations complete before TransitionScreen appears
- [ ] TransitionScreen blocks all clicks underneath it
