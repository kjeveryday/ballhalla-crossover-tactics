extends Node
# BeatManager — Autoload
# Owns all possession/beat/action-pool logic.
# Register as autoload #4 in Project Settings (after ShotClock).

const BEATS_PER_POSSESSION: int = 8
const ACTIONS_PER_BEAT: int = 3

var current_beat: int = 1
var actions_remaining: int = ACTIONS_PER_BEAT
var active_play = null  # PlayCard — wired in Step 4 (play call system)

signal beat_started(beat_num: int)
signal beat_ended(beat_num: int)
signal possession_ended()
signal action_committed(action_type: String)
signal action_resolved()

func start_possession() -> void:
	current_beat = 1
	actions_remaining = ACTIONS_PER_BEAT
	active_play = null
	ShotClock.start()
	print("[BEAT] Possession started — beat 1 of %d" % BEATS_PER_POSSESSION)
	beat_started.emit(current_beat)

func spend_action(action_type: String) -> void:
	action_committed.emit(action_type)
	actions_remaining -= 1
	print("[BEAT] Action '%s' spent — %d remaining" % [action_type, actions_remaining])
	if actions_remaining <= 0:
		end_beat()

func end_beat() -> void:
	print("[BEAT] Beat %d ended" % current_beat)
	beat_ended.emit(current_beat)
	_resolve_in_motion_ballers()
	_resolve_enemy_movement()
	_resolve_enemy_actions()
	_apply_idle_recovery()
	_expire_active_play()
	ShotClock.decrement_beat()
	if current_beat >= BEATS_PER_POSSESSION:
		print("[BEAT] Possession ended after beat %d" % current_beat)
		possession_ended.emit()
	else:
		current_beat += 1
		actions_remaining = ACTIONS_PER_BEAT
		_check_double_team_triggers()
		print("[BEAT] Beat %d started" % current_beat)
		beat_started.emit(current_beat)

func end_beat_early() -> void:
	print("[BEAT] Beat ended early (%d action(s) unused)" % actions_remaining)
	end_beat()

# --- Beat resolution stubs (wired in later steps) ---

func _resolve_in_motion_ballers() -> void:
	MovementSystem.resolve_all_in_motion()

func _resolve_enemy_movement() -> void:
	EnemyAI.update_enemy_movement()

func _resolve_enemy_actions() -> void:
	EnemyAI.resolve_enemy_actions()

func _apply_idle_recovery() -> void:
	StaminaSystem.apply_idle_recovery()

func _expire_active_play() -> void:
	PlayManager.expire_active_play()

func _check_double_team_triggers() -> void:
	GravitySystem.check_double_team_triggers()
