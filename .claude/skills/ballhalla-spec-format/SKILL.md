---
name: ballhalla-spec-format
description: Format and structure for Ballhalla implementation specs. Use when writing or reviewing a spec for a new mechanic. Triggers on requests to "spec out a mechanic", "write an implementation spec", or "review this spec".
---

# Ballhalla Spec Format

Implementation specs translate design intent into testable behavior. They live in /specs/ as one .md file per mechanic.

## Required Sections (in this order)

1. Source - Design doc path, related ARCHITECTURE.md sections, date
2. What This Mechanic Does - 2-3 paragraphs of design language
3. Data Schema Changes - New/modified Resources, GameConstants
4. Behavior Specification - Numbered, testable assertions
5. Signals - Additions to GameEvents and required listeners
6. Edge Cases and Failure Modes - At least 3
7. Out of Scope - Explicit list of what is NOT included
8. Open Questions for Human - Things the spec writer could not decide

## Quality Standards

- Every behavior assertion must be testable. "Feels punchy" is not testable. "Plays an audio cue within 50ms of impact" is testable.
- Every data schema change must specify types.
- Every signal must include its full payload signature.
- The "Out of Scope" section must exist even if it says "nothing in scope creep was tempting here."

## Anti-Patterns to Avoid

- Vague behaviors like "the system should be balanced"
- Implementation details leaking into the spec
- Missing edge cases (always ask: what if the unit is dead, what if the list is empty, what if the action is cancelled mid-execution)

## Template Location

The canonical template lives at .claude/templates/spec_template.md. Start from there.
