# Ballhalla: Crossover Tactics — Development Roadmap

## How This Document Works

This is the **single source of truth** for what to build next. After each `/implement-mechanic` run,
`ballhalla-doc-updater` moves the completed item to the Done table and updates what's next.

- **Mechanic ID** = the argument passed to `/implement-mechanic <id>`
- **Depends on** = IDs that must ship before this one starts
- **Design doc** = read this before running the pipeline; create it if it doesn't exist yet
- Items marked **⚡ DECIDE FIRST** are design questions whose answers affect everything downstream — settle them before writing code in that area

---

## Phase 0 — Decisions Before Code ⚡

These are not implementation tasks. They are design questions you answer as the human.
Each one has significant downstream repercussions. Work through them in order — later decisions
depend on earlier ones.

| # | Question | Why It Matters | Deadline |
|---|----------|---------------|---------|
| D1 | ✅ **RESOLVED — 9×12 grid is final.** Zone boundaries in `GridManager.get_zone()` are locked. No dimension changes. | — | — |
| D2 | **Is multi-beat movement the right feel?** Currently ballers set `is_in_motion` and advance 1 step/beat until they arrive. Alternative: instant commit with stamina cost. Multi-beat creates interesting gameplay (screens, grabs) but complicates animation and AI. | Affects Phase 2 & Step 17 animations | Before 2.3 |
| D3 | ✅ **RESOLVED — Shot clock is real.** Expiry triggers `AbilitySystem._handle_turnover()` through `BeatManager`. See `ARCHITECTURE.md` and `docs/mechanics/shot-clock-enforcement.md`. | — | — |
| D4 | **How complex should plays get?** Currently: 4 plays, linear sequences, 1-beat duration. Options: keep as-is / add multi-beat plays / add branching conditions. Rewrite cost scales with ambition. | Affects Phase 6 scope | Before 6.2 |
| D5 | **What is the full game scope?** Single match → main menu? Campaign with roster and progression? Permadeath? The save system design and scene structure depend entirely on this. | Affects Phase 5 | Before 5.1 |
| D6 | **Is the BallerStats schema locked?** Adding or renaming a stat field requires editing all .tres files and every system that reads them. Review fields now: are `gravity_base` and `hype_charge_rate` staying as floats, or should they become tunable curves? | Affects Phase 6 content | Before 6.3 |

---

## Phase 1 — Critical Repairs

Fix what's broken or incomplete today. These are small, targeted changes — not new features.
All are unblocked and can be done in any order unless noted.

### `occupant-tracking`
**What:** `GridCell.occupant` is never set or cleared by any system. `TargetOverlay` uses it to
filter valid move destinations but it's always null — ballers can legally "move through" each other.
Fix: set occupant in `Baller.place_on_grid()`, clear it on departure.
**Why first:** Every spatial mechanic downstream (movement range, pathfinding, targeting) reads
occupancy. This is a one-file bug that quietly corrupts all of Phase 2.
**Design doc:** `docs/mechanics/occupant-tracking.md` (create before running)
**Files:** `entities/baller/Baller.gd`, `autoloads/GridManager.gd`
**Depends on:** nothing

---

### `turnover-fix`
**What:** `AbilitySystem._handle_turnover()` clears `has_ball`, prints a TODO, and stalls the game.
Fix: emit `turnover_occurred`, call `QuarterManager.end_possession()`, wire `FloatingTextSpawner`
to show "TURNOVER!" text.
**Why first:** Game becomes unplayable on any turnover. Unresolvable edge case.
**Design doc:** `docs/mechanics/turnover-fix.md` (create before running)
**Files:** `autoloads/AbilitySystem.gd`
**Depends on:** nothing

---

### `shot-clock-enforcement`
**What:** Implement whichever model you chose in D3. If real: wire `ShotClock` to trigger a
turnover on expiry through `BeatManager`. If cosmetic: hide the clock and document that the
8-beat possession cap is the official rule.
**Why here:** Either the display is lying or the rule is broken. Both outcomes mislead the player.
**Design doc:** `docs/mechanics/shot-clock-enforcement.md` (create before running)
**Files:** `autoloads/ShotClock.gd`, `autoloads/BeatManager.gd`
**Depends on:** `turnover-fix`, D3 resolved

---

## Phase 2 — Grid & Movement

`GridManager` already has BFS reachability (`mark_reachable_cells`) and path reconstruction
(`get_path_to_cell`). Neither is used at runtime — `MovementSystem` and `EnemyAI` both use greedy
axis-choice step-toward. This phase wires the existing infrastructure up properly.

Build order is strict: each item feeds the next.

---

### `grid-cell-types`
**What:** Extend `GridCell` with a `passable: bool` flag (for future screens-as-obstacles, out-of-bounds
enforcement, etc.) and ensure zone is queryable per cell. Define a `GridCellConfig` resource so courts
can be authored via .tres overrides rather than purely computed. Ties tightly into `occupant-tracking`.
**Why first in Phase 2:** All pathfinding quality depends on the grid accurately representing what
is and isn't traversable.
**Design doc:** `docs/mechanics/grid-cell-types.md` (create before running)
**Files:** `autoloads/GridManager.gd`, new `resources/GridCellConfig.gd`
**Depends on:** `occupant-tracking`, D1 resolved
**User decision:** Should cell passability be static (defined at court load) or dynamic (a screen
temporarily blocks a cell)?

---

### `movement-range-highlight`
**What:** When Move is chosen, highlight reachable cells using BFS from
`GridManager.mark_reachable_cells()` with the baller's actual move range from
`AbilitySystem.get_move_range()`. Currently `TargetOverlay.show_move_range()` hardcodes range=3
regardless of baller speed stat.
**Why here:** Incorrect move range is a visible gameplay bug. Fixing it also forces `TargetOverlay`
to properly read `AbilitySystem` instead of guessing.
**Design doc:** `docs/mechanics/movement-range-highlight.md` (create before running)
**Files:** `scenes/battle/TargetOverlay.gd`, `autoloads/AbilitySystem.gd`
**Depends on:** `grid-cell-types`

---

### `true-pathfinding`
**What:** Replace the greedy axis-choice step-toward in `MovementSystem._pathfind_one_step()` and
`EnemyAI._move_one_step_toward()` with BFS path reconstruction using the existing
`GridManager.get_path_to_cell()`. Ballers navigate around occupied cells rather than through them.
**Why here:** Grid and move range must be correct first. This is the most visible gameplay improvement
in the "grid stuff" bucket — units that walk intelligently vs. units that clip through each other.
**Design doc:** `docs/mechanics/true-pathfinding.md` (create before running)
**Files:** `autoloads/MovementSystem.gd`, `autoloads/EnemyAI.gd`
**Depends on:** `movement-range-highlight`, D2 resolved

---

### `path-preview`
**What:** During Move targeting, hovering a destination cell shows the computed BFS path as a dotted
line before the player commits. Nearly free once `true-pathfinding` exists — reuses the same
`get_path_to_cell()` call.
**Why here:** High UX impact, low implementation cost. Player sees exactly where their baller will
walk before clicking.
**Design doc:** `docs/mechanics/path-preview.md` (create before running)
**Files:** `scenes/battle/TargetOverlay.gd`, `scenes/battle/BattleDemo.gd`
**Depends on:** `true-pathfinding`

---

## Phase 3 — Battle Scene Polish (Steps 15–22)

Full design docs exist for all eight steps in `docs/step-NN-*.md`. Implement in order — each
step has a hard dependency on the previous. Before starting, check `specs/` and `reviews/` for
each mechanic name to see if earlier commits partially completed any of them.

All Phase 3 items depend on **Phase 2 being complete.** Animations in Step 17 are meaningless if
pathfinding is still greedy, and visual bars in Step 16 need correct stamina signals from Step 15A.

---

### `stamina-signal` (Step 15A — foundational for all of Phase 3)
**What:** Add `stamina_changed(baller, delta)` to `StaminaSystem`. Emit on drain and heal.
This signal is wired by Steps 16 (visual bars), 17 (floating text timing), and 22 (undo detection).
**Design doc:** `docs/step-15-floating-text.md` (section 15A)
**Files:** `autoloads/StaminaSystem.gd`
**Depends on:** Phase 2 complete

### `floating-text` (Step 15)
**Design doc:** `docs/step-15-floating-text.md`
**Depends on:** `stamina-signal`

### `baller-visuals` (Step 16)
**Design doc:** `docs/step-16-baller-visuals.md`
**Depends on:** `floating-text`
**User decision ⚡:** Z-order when two ballers occupy the same cell — which renders on top?

### `movement-animations` (Step 17)
**Design doc:** `docs/step-17-animations.md`
**Depends on:** `baller-visuals`

### `enemy-info-panel` (Step 18)
**Design doc:** `docs/step-18-enemy-info.md`
**Depends on:** `movement-animations`

### `action-menu-polish` (Step 19)
**Design doc:** `docs/step-19-action-menu-polish.md`
**Depends on:** `enemy-info-panel`

### `hud-overhaul` (Step 20)
**Design doc:** `docs/step-20-hud-overhaul.md`
**Depends on:** `action-menu-polish`

### `transition-screens` (Step 21)
**Design doc:** `docs/step-21-transition-screens.md`
**Depends on:** `hud-overhaul`

### `game-flow-qol` (Step 22)
**Design doc:** `docs/step-22-game-flow-qol.md`
**Depends on:** `transition-screens`

---

## Phase 4 — AI Improvements

Once the core loop is correct and polished, make the opponent worth playing against.

### `enemy-formations`
**What:** Replace hardcoded 2-3 zone in `EnemyFormation` with a `FormationConfig` resource.
Add man-to-man and 1-3-1 formations. Player can see what formation they're attacking before the
possession starts — surfacing this early affects pre-snap decisions.
**Design doc:** `docs/mechanics/enemy-formations.md` (create before running)
**Files:** `autoloads/EnemyFormation.gd`, new `resources/FormationConfig.gd`
**Depends on:** Phase 3 complete

### `enemy-ai-strategy`
**What:** Replace probabilistic action selection (`_roll_action_count`) with a priority-based
decision tree: evaluate threat level → prioritize high-gravity targets → prefer fouls when ball
carrier is in scoring position → use real pathfinding from Phase 2. Currently the AI takes random
actions regardless of game state.
**Design doc:** `docs/mechanics/enemy-ai-strategy.md` (create before running)
**Files:** `autoloads/EnemyAI.gd`
**Depends on:** `enemy-formations`, `true-pathfinding`

### `steal-and-block`
**What:** Add steal attempt (enemy adjacent to ball carrier, roll against `handle` stat) and
block attempt (enemy within 1 cell of shooter during `SHOT_RESOLVING`, roll against `block_rating`
vs `shooting_*pt`). Enemy AI currently can only foul, grab, and trash-talk — no actual defense.
**Design doc:** `docs/mechanics/steal-and-block.md` (create before running)
**Files:** `autoloads/AbilitySystem.gd`, `autoloads/EnemyAI.gd`, `autoloads/ShotSystem.gd`
**Depends on:** `enemy-ai-strategy`

---

## Phase 5 — Game Structure

Requires D5 (game scope) to be resolved before starting.

### `save-load`
**What:** Serialize match state (scores, quarter, per-baller hype/stamina, active play) to a
Resource using `ResourceSaver`. Load on resume. Per `CLAUDE.md`: every saveable Resource needs
`save_version: int` for migration.
**Design doc:** `docs/mechanics/save-load.md` (create before running)
**Files:** new `src/core/SaveManager.gd`, new `resources/SaveData.gd`
**Depends on:** Phase 3 complete, D5 resolved

### `main-menu`
**What:** Title screen with New Game / Continue. Loads correct scene based on save state.
**Design doc:** `docs/mechanics/main-menu.md` (create before running)
**Files:** new `scenes/ui/MainMenu.gd`, new `scenes/ui/main_menu.tscn`
**Depends on:** `save-load`

### `match-result-screen`
**What:** Post-match full box score, MVP designation, hype totals. Transitions to main menu or
next opponent.
**Design doc:** `docs/mechanics/match-result-screen.md` (create before running)
**Files:** new `scenes/ui/MatchResultScreen.gd`
**Depends on:** `main-menu`

---

## Phase 6 — Content & Balance

### `data-driven-constants`
**What:** Audit all autoloads and extract every hardcoded numeric value (action costs, stamina
penalties, hype thresholds, AI probabilities, zone shot bonuses, distance thresholds) into
`src/core/GameConstants.gd` or dedicated tuning .tres resources. Zero magic numbers in system code.
**Why:** You cannot tune balance on values you have to grep for.
**Design doc:** `docs/mechanics/data-driven-constants.md` (create before running)
**Files:** `src/core/GameConstants.gd`, all autoloads (read/extract only, no logic changes)
**Depends on:** Phase 4 complete

### `playbook-expansion`
**What:** Add 4+ new plays with varied sequences and bonuses. Move play definitions out of
`PlayManager` into `PlaybookConfig` .tres resources so plays can be authored without code changes.
**Design doc:** `docs/mechanics/playbook-expansion.md` (create before running)
**Files:** `autoloads/PlayManager.gd`, new `resources/PlaybookConfig.gd`
**Depends on:** `data-driven-constants`, D4 resolved

### `new-team`
**What:** Author a second complete opposing team (5 × BallerStats .tres files) with a distinct
tactical archetype. Use a formation from `enemy-formations`. First test of whether the stat schema
works for genuinely different playstyles.
**Design doc:** `docs/mechanics/new-team.md` (create before running)
**Files:** new `resources/teams/` folder, `autoloads/EnemyFormation.gd`
**Depends on:** `data-driven-constants`, `enemy-formations`, D6 resolved

---

## Design Debt (Known Issues — Not Urgent)

Track here instead of fixing now. Revisit after Phase 3.

| Issue | Location | Notes |
|-------|----------|-------|
| Basketball object unused | `entities/Basketball.gd` | Possession tracked via `baller.has_ball`. Either integrate or delete. |
| BattleDemo monolith | `scenes/battle/BattleDemo.gd` | ~600+ lines mixing input, animation, UI, state. Split after Phase 3. |
| No theme system | All UI components | Colors hardcoded per component. Add Godot Theme resource post-Phase 3. |
| FloatingText not pooled | `src/ui/FloatingText.gd` | Creates/destroys nodes per spawn. Fine for now; revisit if frame drops occur. |
| ShotClock display only | `autoloads/ShotClock.gd` | Resolved by D3 + `shot-clock-enforcement`. |
| Continuation timeout fragile | `autoloads/QuarterManager.gd` | 30s auto-resume on halftime/quarter screens. Replace with explicit user-dismiss signal. |

---

## Done

| Mechanic ID | Commit | Date | Notes |
|-------------|--------|------|-------|
| `occupant-tracking` | f3f47db | 2026-05-17 | Baller.place_on_grid, MovementSystem, EnemyAI all maintain GridCell.occupant |
| `turnover-fix` | — | 2026-05-17 | Already fully implemented: has_ball cleared, turnover_occurred emitted, end_possession called, floating text wired in BattleDemo |
| `shot-clock-enforcement` | — | 2026-05-17 | ShotClock emits shot_clock_expired; BeatManager routes to _handle_turnover. D3 resolved: clock is real. |
| `grid-cell-types` | — | 2026-05-17 | GridCell.passable + movement_cost added; is_out_of_bounds removed; BFS filters impassable; GridCellConfig resource created. D1 resolved: 9×12 final. |
| `movement-range-highlight` | — | 2026-05-17 | TargetOverlay show_move_range/show_cut_range/preview_move_range all use AbilitySystem.get_move_range; show_move_range switches to mark_reachable_cells for BFS caching. |
