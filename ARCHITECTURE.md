# ARCHITECTURE.md

This file records architectural decisions for the Ballhalla project.
Add entries below as decisions are made.

## Format
**Decision:** [what was decided]
**Rationale:** [why]
**Tradeoff accepted:** [what we gave up]

---

## D2 — Multi-beat movement confirmed; screens are soft fields

**Decision:** Ballers advance one grid step per beat until they reach their destination (`is_in_motion` pattern). Movement is NOT instant-commit. Screens do not create hard passability blocks — they elevate `movement_cost` on adjacent cells, creating a stamina/range penalty rather than a wall. The enemy baller getting screened also takes a direct stamina hit.

**Rationale:** Multi-beat movement enables screens, grabs, and interception windows between the action and arrival. Instant movement would eliminate those tactical layers. Hard blocks create degenerate positions (screener permanently walls off a lane); soft fields preserve routing options while rewarding good screen placement.

**Tradeoff accepted:** Pathfinding must store the full pre-computed route at initiation so each beat's step follows the BFS-optimal path rather than recomputing from scratch. BFS must become cost-aware rather than reachability-only (weighted BFS / Dijkstra) to respect `movement_cost`.

---

## D1 — 9×12 grid is final

**Decision:** The court grid is permanently 9 columns × 12 rows. No dimension changes.

**Rationale:** Zone boundaries in `GridManager.get_zone()` are computed from hardcoded row thresholds. Every spatial calculation, BFS range, and .tres position reference is locked to this layout.

**Tradeoff accepted:** Changing court size later requires auditing every system in Phase 2 and all authored .tres data.

---

## D3 — Shot clock is a real turnover trigger

**Decision:** When the 24-second shot clock expires, possession ends as a turnover. The offense
loses the ball through `AbilitySystem._handle_turnover()`, identical to a pass turnover.

**Rationale:** The clock is visible to the player and should mean something. A display-only
timer is confusing — players will assume it matters. Under current math (8 beats × 3s = 24s)
the clock and beat limit co-expire, but the enforcement path is wired correctly for future
rule changes (e.g., clock reset on offensive rebound).

**Tradeoff accepted:** Two possession-end triggers exist (beat limit and shot clock). They
fire simultaneously today. The guard in `BeatManager.end_beat()` prevents double-fire by
checking `current_beat < BEATS_PER_POSSESSION`.
