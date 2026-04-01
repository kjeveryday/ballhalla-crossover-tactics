# Ballhalla Polish Plan — Steps 15–22

## Overview

This document is the master index for the 8-step polish plan. Each step has its own detailed file.

Steps 1–14 built the core systems (grid, state machine, entities, beat manager, abilities, shot system, play calls, quarter manager). Steps 15–22 bring the battle scene up to par with commercial tactics games.

## Architectural Principles

Three cross-cutting rules prevent the features from conflicting:

1. **Animations never own game state.** Grid positions update instantly. Tweens only move sprite `.position`, so BeatManager never waits on visuals.
2. **QuarterManager owns all pacing gates.** Every transition screen pause goes through a `_continuation: Callable` stored in QuarterManager. The UI calls it when ready; QuarterManager never calls `BeatManager.start_possession()` directly anymore.
3. **TargetOverlay has two modes: interactive and preview.** Preview mode draws highlights but never intercepts input. This keeps hover-preview and selection-targeting from conflicting.

## Step Index

| Step | File | Summary |
|------|------|---------|
| 15 | [step-15-floating-text.md](step-15-floating-text.md) | FloatingText system + StaminaSystem.stamina_changed signal |
| 16 | [step-16-baller-visuals.md](step-16-baller-visuals.md) | Stamina bars, exhausted dimming, acted indicator, ball carrier glow, ISO ring |
| 17 | [step-17-animations.md](step-17-animations.md) | Movement tween, pass animation, shot arc overlay, input guard |
| 18 | [step-18-enemy-info.md](step-18-enemy-info.md) | Enemy info panel, guard assignment display, D-key toggle cycle |
| 19 | [step-19-action-menu-polish.md](step-19-action-menu-polish.md) | Keyboard hints, stamina costs, hover previews, play descriptions |
| 20 | [step-20-hud-overhaul.md](step-20-hud-overhaul.md) | Scoreboard panel, active play banner, baller info bar, hype milestone FX |
| 21 | [step-21-transition-screens.md](step-21-transition-screens.md) | Defense phase screen, quarter end, halftime choice, QuarterManager architecture |
| 22 | [step-22-game-flow-qol.md](step-22-game-flow-qol.md) | Undo move, tab cycling, end beat confirmation, turnover fix, match log panel |

## Implementation Order

Steps must be done in sequence — each depends on the previous:

```
15 → 16 → 17 → 18 → 19 → 20 → 21 → 22
```

- **15 first**: FloatingText and stamina signals feed into every other step.
- **16 before 22**: Tab cycling is meaningful once acted/exhausted state is visually clear.
- **17 before 21**: TransitionScreen waits on `_is_animating`; the flag must exist first.
- **18 before 19**: EnemyInfoPanel's dismiss-on-ActionMenu-open logic needs both systems.
- **19 before 20**: ActionMenu's undo button (Step 22 state) and hover previews share the same panel.
- **20 before 21**: The HUD panels that TransitionScreen hides must exist first.
- **21 before 22**: Turnover fix routes through QuarterManager's new continuation architecture.

## Interaction Map

```
Step 15 (FloatingText + Signal)
    └── feeds visual feedback to Steps 16, 17, 18, 21, 22

Step 16 (Baller Tokens)
    └── reads acted_this_beat (used by Step 22 Tab cycling)
    └── draws ISO ring (driven by PlayManager, shown in Step 20 banner)

Step 17 (Animations)
    └── _is_animating blocks all input (Steps 18, 19, 22)
    └── delays Step 21 TransitionScreen until animations finish

Step 18 (Enemy Info + Guard Lines)
    └── EnemyInfoPanel hidden by Step 21 TransitionScreen
    └── GuardDisplay shares D-key toggle with zone overlay

Step 19 (ActionMenu Polish)
    └── hover preview uses TargetOverlay PREVIEW mode (non-blocking)
    └── Undo button added here (availability from Step 22 snapshot)

Step 20 (HUD Overhaul)
    └── ScoreboardPanel replaces _status_label
    └── ActivePlayBanner driven by PlayManager signals
    └── HypeMilestoneFX uses new HypeManager.hype_milestone signal
    └── BallerInfoBar updated by _refresh_status() as before

Step 21 (Transition Screens)
    └── QuarterManager._continuation gates all possession flow
    └── TransitionScreen dismisses Steps 18/19 panels before showing
    └── Halftime choice writes back to PlayManager and StaminaSystem
    └── Uses _possession_stats dict from BattleDemo

Step 22 (Game Flow QoL)
    └── Undo snapshot cleared by beat_ended, shot_made
    └── Tab cycling reads acted_this_beat drawn in Step 16
    └── Turnover fix routes through Step 21 TransitionScreen pause
    └── LogPanel consumes same _log() calls as rolling 7-line label
    └── ConfirmDialog uses same StyleBoxFlat style as ActionMenu
```

## Feature Count by Root Cause

| Root Cause | Steps |
|---|---|
| No visual feedback for system events | 15, 16, 20 |
| Missing animation/motion | 17 |
| Game state legibility | 16, 18, 20 |
| Missing transition screens | 21 |
| UX / input polish | 19, 22 |
| Unfinished system (turnover) | 22 |
| Content (tooltips, descriptions) | 19 |
