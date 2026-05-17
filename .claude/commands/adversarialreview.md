# /adversarialreview — Adversarial Code Review

Spin up a critic agent that compares the session's implementation against the design
docs, looking for gaps, type errors, and unconnected wiring.

## Step 1 — Gather context

Run these in parallel:

1. `git diff HEAD~5..HEAD --stat` — which files changed in recent commits
2. `git diff HEAD~5..HEAD` — full diff of recent work
3. Read `docs/roadmap.md` — identify which mechanics are in the Done table

For each mechanic in the Done table that has a design doc under `docs/mechanics/`,
note its file path.

## Step 2 — Spawn the critic agent

Use the `Agent` tool with this prompt (fill in the blanks from Step 1):

---
You are an adversarial code reviewer for a Godot 4.4 GDScript TRPG project called
Ballhalla: Crossover Tactics. Your job is to find gaps — things that were supposed to
be implemented but weren't, or were implemented incorrectly.

**Recent git diff:**
[paste full diff]

**Mechanics reviewed this session:**
[list mechanic IDs and their design doc paths]

**For each mechanic, read its design doc and then check:**

1. **Behavior coverage** — every behavior row (B1, B2, …) in the design doc has
   corresponding code. If a behavior has no code path, flag it as MISSING.

2. **Signal wiring** — every signal declared is connected somewhere. Use Grep to
   search for `.connect(` calls referencing each signal. Flag any declared but
   never-connected signals as UNWIRED.

3. **Type safety** — all new variables, parameters, and return values have explicit
   types. Flag any untyped declarations as TYPE_MISSING.

4. **Edge cases** — null guards where needed (especially `get_cell()` returns null for
   OOB coords, `get_ball_carrier()` can return null, `baller.stats` may be unset in
   tests). Flag missing null checks as NULL_RISK.

5. **BeatManager double-fire** — any new path that calls `possession_ended.emit()` or
   `QuarterManager.end_possession()` must not be reachable when another path already
   fired it in the same frame. Flag potential double-fires as DOUBLE_FIRE.

6. **Roadmap consistency** — check that the Done table in `docs/roadmap.md` accurately
   reflects what's actually in code. Flag any mechanics listed as Done where the code
   evidence is thin or missing as ROADMAP_MISMATCH.

**Output format:**
Produce a markdown report with one section per mechanic. Each finding uses a tag:
MISSING | UNWIRED | TYPE_MISSING | NULL_RISK | DOUBLE_FIRE | ROADMAP_MISMATCH

End with a verdict:
- ✅ CLEAN — no findings
- ⚠️ MINOR — findings exist but nothing blocks shipping
- 🔴 CRITICAL — at least one MISSING or DOUBLE_FIRE finding

Read the relevant source files directly using the Read and Grep tools. Do not guess.
---

## Step 3 — Present the report

Show the full report to the user. If the verdict is 🔴 CRITICAL, ask whether to fix
the issues now or log them as design debt and continue.

If ✅ CLEAN or ⚠️ MINOR, say: "Review complete. Ready to continue — just say 'back
to work' or pick the next item."
