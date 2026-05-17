# ARCHITECTURE.md

This file records architectural decisions for the Ballhalla project.
Add entries below as decisions are made.

## Format
**Decision:** [what was decided]
**Rationale:** [why]
**Tradeoff accepted:** [what we gave up]

---

## D2 (partial) — Screens are soft movement fields, not hard blocks

**Decision:** Screen actions do not set any cell to impassable. Instead, cells adjacent to the screener carry an elevated `movement_cost`. BFS pathfinding sums cost along the path — moving through a screen zone costs more stamina/movement points but is never forbidden. The enemy baller getting screened also takes a direct stamina hit.

**Rationale:** Hard blocks create degenerate positions (screener permanently walls off a lane). Soft fields preserve routing options while rewarding good screen placement.

**Tradeoff accepted:** BFS must become cost-aware rather than reachability-only. Weighted BFS (Dijkstra) replaces simple flood-fill for movement range.

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
