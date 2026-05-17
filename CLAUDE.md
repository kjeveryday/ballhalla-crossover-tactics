# CLAUDE.md

## Architecture Rules (Non-Negotiable)
- Stat math and data schemas live in Resources. Frame-driven behavior
  and orchestration live in Nodes.
- Resources never reach into the scene tree. No get_tree(), no get_node(),
  no signal emissions to specific scene paths from inside a Resource.
- Cross-system communication goes through GameEvents (the autoload signal bus).
- Never use get_node() with a hardcoded path. Use @export or dependency injection.

## Persistence
- Saves use Godot's native ResourceSaver to .res files in user://.
- Every saveable Resource has a save_version: int property for migration.

## Code Style
- Strict typing on every variable, parameter, and return value.
- No magic numbers. Constants live in GameConstants.
- Snake_case for variables and functions. PascalCase for classes and signals.
- Signals: past tense for events (unit_moved), verb phrase for requests (request_move).

## Files to Read Before Modifying Anything
- /src/core/GameConstants.gd
- /src/core/BattleController.gd
- /src/core/TurnController.gd
- /src/data/UnitData.gd
- /autoloads/GameEvents.gd

## Dynamic Documentation
After any refactor that changes a Resource schema, renames a signal, or
modifies a system's public interface, update CLAUDE.md and ARCHITECTURE.md
before starting the next task.

## Static Analysis
Every commit must pass gdlint .

---

## Agentic Pipeline — How to Run /implement-mechanic

When the user runs `/implement-mechanic <name>`, you are the orchestrator.
Run the six stages below in order using the **Agent tool** for each subagent.
Never skip a stage. Never auto-advance past a human checkpoint.

### Tool to use
Spawn each subagent with the `Agent` tool using `run_in_background: true`.
Pass the project root, the mechanic name, and the relevant file paths in the prompt.
Do NOT use the Task tool to invoke subagents — use Agent.

### Background execution and verification
- Always spawn agents with `run_in_background: true` so the session stays responsive.
- You will be notified automatically when each agent completes — do not poll or sleep.
- When notified, **verify the agent's output before advancing** to the next stage:
  - Confirm the expected file was written to disk (Read it or check it exists).
  - Check that the agent's returned summary matches what was requested.
  - If verification fails, re-run the agent with the failure details before continuing.
- Never advance to the next stage on the agent's word alone — confirm the artifact exists.

### Stage 1 — Design Translation
Agent: `ballhalla-design-translator`
Input: mechanic name, path to its design doc under `/docs/`
Output: spec file written to `/specs/<name>.md`

> **CHECKPOINT 1 — STOP HERE.**
> Read the spec aloud (path + one-paragraph summary). Wait for the user to
> say "approve" before proceeding. Do not auto-advance.

### Stage 2 — Test Authoring
Agent: `ballhalla-test-author`
Input: path to the approved spec
Output: `/tests/test_<name>.gd` — tests exist and fail (no implementation yet)

One-line status update to user, then immediately proceed to Stage 3.

### Stage 3 — Implementation
Agent: `ballhalla-implementer`
Input: spec path + test file path
Output: implementation files; all tests green; gdlint clean

If tests still fail after two agent iterations, surface the specific failure to
the user. Do not loop silently.

### Stage 4 — Code Review
Agent: `ballhalla-reviewer`
Input: `git diff` context
Output: review report at `/reviews/<name>.md`

If the report contains **Critical** findings: spawn the implementer again with
the report as additional input. Do not advance to Stage 5 until Critical count
is zero.

### Stage 5 — Integration Testing
Agent: `ballhalla-integration-tester`
Input: spec path
Output: integration report at `/reviews/<name>_integration.md`

> **CHECKPOINT 2 — STOP HERE.**
> Show the verdict. Tell the user to play the feature in Godot and reply
> "accept" or send revision notes. Do not auto-advance.

### Stage 6 — Documentation Update
Agent: `ballhalla-doc-updater`
Input: full `git diff` context + spec path
Output: edits to CLAUDE.md / ARCHITECTURE.md, or "no changes needed"

> **CHECKPOINT 3 — STOP HERE.**
> Summarize: what was built, test count, whether docs were touched.
> Ask: commit now, or hand off to Cursor for aesthetic polish?

### Between-stage discipline
- One line of status between stages: "Stage 2 complete. Moving to Stage 3."
- Save detail for checkpoints.
- Never summarize a stage's full output mid-run.

### Design doc location convention
Design docs live in `/docs/step-NN-<name>.md`. When invoking the design
translator, find the matching doc by searching `/docs/` for the mechanic name.
If no doc exists, stop and ask the user to create one before the pipeline runs.

---

## Intuitive Continuation — What to Build Next

When the user says something like "continue", "let's go", "next", "keep going",
or any vague forward prompt that does NOT name a specific mechanic, do this:

### Step 1 — Read the live roadmap
The authoritative build order lives at:
`C:\Users\Kyle\Desktop\ballhalla-crossover-tactics\docs\roadmap.md`

Find the earliest Phase that has items not yet in the **Done** table.
Within that Phase, pick the first item whose **Depends on** items are all Done.
Do NOT guess or use a hardcoded sequence — `ballhalla-doc-updater` keeps this file current.

### Step 2 — Check for in-progress work
A mechanic is **complete** when ALL of the following exist:
- `/specs/<name>.md` — spec was approved
- `/tests/test_<name>.gd` — tests written
- `/reviews/<name>.md` — code review passed (no Critical findings)
- `/reviews/<name>_integration.md` — integration test passed

A mechanic is **in progress** if some but not all of those files exist.
If one is in progress, resume it from the first missing file rather than starting fresh.

### Step 3 — Tell the user, then run
One sentence: "Picking up [mechanic name] from the backlog. Running Stage N."
Then invoke the pipeline. Do not ask for further confirmation unless a CHECKPOINT is reached.

---

## Quick Detours

These commands are always available. When asking the user a question at any decision
point or design question, append this block after the question:

```
Quick detours (say the command — we'll pick up where we left off after):
  /testgame — launch Godot to manually test recent changes
  /adversarialreview — critic agent audits session code for gaps before proceeding
```

**After a detour:** When the user returns (says "back to work", "done", "continue", or
similar), restate in one sentence what question was open before the detour, then wait
for the answer.

**Adding new detours:** Create a new `.md` file in `.claude/commands/`. Add its name
and a one-line description to the Quick Detours block above so it appears automatically
at every decision point.
