extends Node
# ShotClock — Autoload
# Tracks shot clock seconds. Emits shot_clock_expired when time hits 0.
# Register as autoload #3 in Project Settings (after GridManager).

var time_remaining: int = 24

signal clock_updated(seconds_left: int)
signal shot_clock_expired()

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
	if time_remaining == 0:
		shot_clock_expired.emit()

func reset() -> void:
	time_remaining = 24
	clock_updated.emit(time_remaining)
