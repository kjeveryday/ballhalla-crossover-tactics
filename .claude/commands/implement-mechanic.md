---
description: Run the six-stage agentic pipeline to implement a Ballhalla mechanic from design doc to integrated, tested feature
allowed-tools: Task, Read, Write, Bash, Grep, Glob
---

# Implement Mechanic: $ARGUMENTS

You are the orchestrator for the Ballhalla agentic development pipeline. Run six stages sequentially, with three human checkpoints. Do not skip checkpoints. Do not auto-advance past human approval.

## Stage 1: Design Translation
Invoke ballhalla-design-translator subagent via Task tool with input: mechanic name = $ARGUMENTS.
Expected output: spec file at /specs/$ARGUMENTS.md.

### CHECKPOINT 1
After the spec is produced, STOP. Tell the user:
- Where the spec lives
- A one-paragraph summary of what it covers
- That you await their approval to proceed

Do not invoke Stage 2 until the user explicitly approves.

## Stage 2: Test Authoring
Once approved, invoke ballhalla-test-author with input: spec path.
Expected output: test file at /tests/test_$ARGUMENTS.gd, tests run but fail as expected.

## Stage 3: Implementation
Invoke ballhalla-implementer with input: spec plus test paths.
Expected output: implementation files; all tests passing; gdlint clean.

If implementation fails after multiple iterations, surface the failure to the user with specifics. Do not silently continue.

## Stage 4: Code Review
Invoke ballhalla-reviewer with input: git diff context.
Expected output: review report at /reviews/$ARGUMENTS.md.

If Critical findings exist, return to Stage 3 with the findings as additional input. Do not advance.

## Stage 5: Integration Testing
Invoke ballhalla-integration-tester with input: spec path.
Expected output: integration report.

### CHECKPOINT 2
After the report is produced, STOP. Tell the user:
- The report verdict
- That they should play the feature and either accept or reject
- That you await their acceptance to proceed

## Stage 6: Documentation Update
Once accepted, invoke ballhalla-doc-updater with input: full diff context.
Output: doc updates or "no changes needed".

### CHECKPOINT 3
After docs are updated, STOP. Tell the user:
- Summary of what was built
- Test counts
- Whether docs were touched
- Ask if they want to commit, or hand off to Cursor for aesthetic polish first

## Output Discipline

Between stages, give the user a one-line status update like "Stage 2 complete. Moving to Stage 3." Don't summarize each stage's output extensively. Save the detail for the checkpoints.
