extends Node
# ShotClock — Autoload
# Display-only counter. No gameplay logic — BeatManager drives all state.
# Register as autoload #3 in Project Settings (after GridManager).

var time_remaining: int = 24

signal clock_updated(seconds_left: int)

func start() -> void:
	time_remaining = 24
	clock_updated.emit(time_remaining)
	if OS.is_debug_build():
		print("[CLOCK] Started at 24")

func decrement_beat() -> void:
	time_remaining = max(0, time_remaining - 3)
	clock_updated.emit(time_remaining)
	if OS.is_debug_build():
		print("[CLOCK] → %d" % time_remaining)

func reset() -> void:
	time_remaining = 24
	clock_updated.emit(time_remaining)
