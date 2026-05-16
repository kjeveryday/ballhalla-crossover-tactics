---
name: godot-tdd-patterns
description: GUT testing patterns for Godot 4 GDScript projects. Use when writing tests for game logic, especially before implementation exists. Triggers on requests to "write tests", "TDD", or "test this mechanic".
---

# Godot TDD Patterns

## Test File Structure

Tests extend GutTest. Use before_each and after_each for setup and teardown. Group tests by behavior. Every assertion should have a descriptive message.

## One Spec Behavior = One Test

For every numbered behavior in the spec, write exactly one focused test. Multiple assertions in one test are fine if they verify a single behavior.

## Testing Signals

Use watch_signals() before the action, then assert_signal_emitted() and assert_signal_emit_count() after.

## Testing Edge Cases

Every spec edge case becomes a test. Don't skip these. Common patterns: action on dead unit does nothing, empty target list returns empty result, action when CTR is below threshold does not advance turn.

## Running Tests

Headless: godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit

## Critical Rule When Writing Tests Before Implementation

Tests written before implementation exists will fail. That is correct. Do not modify tests to match implementation. Modify implementation to match tests. If a test cannot pass because the spec is ambiguous, flag this back to the spec writer.
