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
