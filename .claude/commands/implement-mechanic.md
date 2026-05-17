---
description: Run the six-stage agentic pipeline to implement a Ballhalla mechanic from design doc to integrated, tested feature
allowed-tools: Agent, Read, Write, Edit, Bash, Grep, Glob
---

# Implement Mechanic: $ARGUMENTS

You are the orchestrator for the Ballhalla agentic development pipeline.
Project root: `C:\Users\Kyle\Desktop\ballhalla-crossover-tactics`

Run six stages sequentially with three human checkpoints.
**Spawn each subagent using the Agent tool.** Do not skip checkpoints. Do not auto-advance past human approval.

---

## Stage 1: Design Translation

Search `/docs/` for a file whose name contains "$ARGUMENTS". Pass that path to the agent.

Spawn Agent with this prompt:
> You are ballhalla-design-translator. Read the design doc at [doc path]. Read CLAUDE.md and ARCHITECTURE.md. Read .claude/templates/spec_template.md and .claude/skills/ballhalla-spec-format/SKILL.md. Do NOT read implementation files. Produce a spec at specs/$ARGUMENTS.md. Return: the spec path, a one-paragraph summary, and the full spec text.

Expected output: `specs/$ARGUMENTS.md`

### CHECKPOINT 1 — STOP
Present the spec path and one-paragraph summary. Tell the user to review `specs/$ARGUMENTS.md` and reply "approve" to continue. Do not proceed until approved.

> Quick detours: `/testgame` to check current state in-engine · `/adversarialreview` to audit prior session work before adding more

---

## Stage 2: Test Authoring

Spawn Agent with this prompt:
> You are ballhalla-test-author. Read specs/$ARGUMENTS.md. Read .claude/skills/godot-tdd-patterns/SKILL.md. Read existing tests in /tests/ for style reference only. Write tests/test_$ARGUMENTS.gd — one test per spec behavior, one per edge case, one per signal. Do NOT read implementation source for this mechanic. Return: test file path and test count.

Expected output: `tests/test_$ARGUMENTS.gd` (tests exist and fail — that is correct)

Status update: "Stage 2 complete. Moving to Stage 3."

---

## Stage 3: Implementation

Spawn Agent with this prompt:
> You are ballhalla-implementer. Read specs/$ARGUMENTS.md and tests/test_$ARGUMENTS.gd. Read .claude/skills/gdscript-style/SKILL.md. Read existing source in entities/ and autoloads/ for context. Implement minimum code to make all tests pass. Run tests headless after each iteration. Do not modify tests. Return: files created/modified, test results, any API calls you verified, the single most likely failure mode.

Expected output: implementation files; all tests green; gdlint clean.

If tests still fail after reporting back, spawn the implementer again with the failure details. Surface to user if it fails twice.

---

## Stage 4: Code Review

Spawn Agent with this prompt:
> You are ballhalla-reviewer. Run git diff to see all changes. Read CLAUDE.md and ARCHITECTURE.md. Read .claude/skills/godot-anti-patterns/SKILL.md. Produce a review report at reviews/$ARGUMENTS.md with Critical / Warning / Suggestion sections. Include API Verification and Signal Audit sections. Return: report path and "X critical, Y warnings, Z suggestions."

Expected output: `reviews/$ARGUMENTS.md`

If Critical count > 0: spawn ballhalla-implementer again with the review report as additional input. Do not advance until Critical count is zero.

---

## Stage 5: Integration Testing

Spawn Agent with this prompt:
> You are ballhalla-integration-tester. Read specs/$ARGUMENTS.md. Use Godot MCP tools to open the relevant scene, confirm expected nodes exist, trigger the mechanic, and capture console output. For each numbered spec behavior document observed evidence and a verdict (passed / failed / inconclusive). Write report to reviews/$ARGUMENTS_integration.md. Return: report path and overall verdict.

Expected output: `reviews/$ARGUMENTS_integration.md`

### CHECKPOINT 2 — STOP
Show the verdict. Tell the user to open Godot, play the feature, and reply "accept" or send revision notes. Do not proceed until accepted.

> Quick detours: `/testgame` to launch the right scene automatically · `/adversarialreview` for a second set of eyes before accepting

---

## Stage 6: Documentation Update

Spawn Agent with this prompt:
> You are ballhalla-doc-updater. Run git diff. Read CLAUDE.md, ARCHITECTURE.md, and specs/$ARGUMENTS.md. Determine if any new signals, Resource schemas, autoloads, constants, or architectural patterns were added. If yes, edit CLAUDE.md and/or ARCHITECTURE.md with the specific additions. If no, output "no doc changes needed" and explain why.

---

### CHECKPOINT 3 — STOP
Summarize:
- What was built (files created/modified)
- Test count
- Whether structural docs were touched
- What the doc-updater moved to Done and what is now at the top of Next Up
- Ask: commit now, or hand off to Cursor for aesthetic polish first?

> Quick detours: `/testgame` to play the finished mechanic · `/adversarialreview` to stress-test before committing

If the user says **commit** (or any equivalent — "ship it", "yes", "looks good"):
1. Stage all changed files: `git add -A`
2. Commit with a message summarising the mechanic: `git commit -m "feat: implement <mechanic-name> — <one-line summary>"`
3. Push to GitHub: `git push origin main`
4. Report the commit hash and confirm: "Pushed to origin/main."

---

## Output Discipline

One line between stages: "Stage N complete. Moving to Stage N+1." Save detail for checkpoints.
