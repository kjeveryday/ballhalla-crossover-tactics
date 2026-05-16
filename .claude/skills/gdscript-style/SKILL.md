---
name: gdscript-style
description: GDScript style and architecture conventions for the Ballhalla project. Use when writing or reviewing any GDScript code. Triggers on requests to "write GDScript", "review code", or any code generation task.
---

# GDScript Style Conventions

## Typing

Every variable, parameter, and return value must be typed. Untyped GDScript is a lint failure.

## Naming

- Variables and functions: snake_case
- Classes (with class_name): PascalCase
- Signals: snake_case past-tense for events (unit_moved), verb phrase for requests (request_move)
- Constants: SCREAMING_SNAKE_CASE
- Private members: leading underscore

## Architecture Rules

- Stat math and data live in Resources. Frame-driven behavior lives in Nodes.
- Resources never call get_tree() or get_node().
- Cross-system communication goes through GameEvents (the autoload signal bus).
- No get_node() with hardcoded paths. Use @export for node references.
- No magic numbers. Constants live in GameConstants.

## Signals on GameEvents

When adding a new signal: declare on GameEvents, emit at the source, connect in _ready() at the listener. Never connect in _init().

## Save-Compatible Resources

Every saveable Resource needs save_version: int as first field, all persistent state marked @export, no Node references in fields.

## Static Analysis

Code must pass gdlint . before being declared complete.
