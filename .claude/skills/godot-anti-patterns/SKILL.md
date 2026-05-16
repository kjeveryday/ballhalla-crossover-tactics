---
name: godot-anti-patterns
description: Common Godot 4 and GDScript anti-patterns to flag during code review. Use when reviewing code, doing PR-style reviews, or auditing a diff. Triggers on requests to "review code", "audit this code", or "check for issues".
---

# Godot Anti-Patterns to Flag

When reviewing code, flag every instance of these patterns. Categorize each finding as Critical, Warning, or Suggestion.

## Critical

- Hallucinated APIs: Any Godot class or method call where you cannot confirm the API exists in Godot 4 docs.
- Resources reaching into the scene tree: get_tree(), get_node(), or scene-path signal emissions inside a Resource.
- Hardcoded node paths: get_node("/root/Main/...") is brittle. Use @export or dependency injection.
- Untyped variables.
- Magic numbers that belong in GameConstants.

## Warning

- Signal listeners connected in _init() instead of _ready().
- as casts without null checks.
- Mutable default arguments shared across Resource instances.
- Dynamic signal connections via get_signal_list().

## Suggestion

- _process() work that could be event-driven.
- Repeated lookups in tight loops that could be cached.
- Functions over 40 lines.

## Report Format

Findings organized by Critical / Warning / Suggestion, with file path, line number, issue, and specific fix. Include explicit API Verification and Signal Audit sections.
