extends Node
# QuarterManager — Autoload
# Quarter/possession loop, scoring, and automated defense phase.
# Replaces the temporary allied_score variable in ShotSystem.

var current_quarter: int = 1
var allied_score: int = 0
var enemy_score: int = 0
var _is_defense_phase: bool = false

signal quarter_ended(quarter: int)
signal match_ended(allied_score: int, enemy_score: int)
signal score_changed(allied: int, enemy: int)

func _ready() -> void:
	BeatManager.possession_ended.connect(_on_possession_ended)

# --- Entry points ---

func start_match() -> void:
	current_quarter = 1
	allied_score = 0
	enemy_score = 0
	_is_defense_phase = false
	GameStateMachine.transition_to(GameStateMachine.BattleState.OFFENSE_START)
	BeatManager.start_possession()

func add_allied_score(points: int) -> void:
	allied_score += points
	print("[SCORE] Allied +%d — Allied %d : Enemy %d" % [points, allied_score, enemy_score])
	score_changed.emit(allied_score, enemy_score)
	end_possession()

func _on_possession_ended() -> void:
	end_possession()

# --- Possession / Quarter flow ---

func end_possession() -> void:
	_reset_ballers_for_next_possession()
	ShotClock.reset()
	if _is_defense_phase:
		end_quarter()
	else:
		_is_defense_phase = true
		GameStateMachine.transition_to(GameStateMachine.BattleState.DEFENSE_PHASE)
		_resolve_defense_phase()

func end_quarter() -> void:
	_is_defense_phase = false
	print("[QUARTER] Quarter %d ended — Allied %d : Enemy %d" % [
		current_quarter, allied_score, enemy_score])
	quarter_ended.emit(current_quarter)
	if current_quarter >= 4:
		_check_overtime()
	elif current_quarter == 2:
		current_quarter += 1
		GameStateMachine.transition_to(GameStateMachine.BattleState.HALFTIME)
	else:
		current_quarter += 1
		GameStateMachine.transition_to(GameStateMachine.BattleState.OFFENSE_START)
		BeatManager.start_possession()

func _check_overtime() -> void:
	if allied_score == enemy_score:
		print("[QUARTER] Overtime! Score tied at %d — extra possession" % allied_score)
		current_quarter += 1
		_is_defense_phase = false
		GameStateMachine.transition_to(GameStateMachine.BattleState.OFFENSE_START)
		BeatManager.start_possession()
	else:
		_end_match()

func _end_match() -> void:
	var winner: String = "Allied" if allied_score > enemy_score else "Enemy"
	print("[MATCH] Game over — %s wins! Allied %d : Enemy %d" % [
		winner, allied_score, enemy_score])
	GameStateMachine.transition_to(GameStateMachine.BattleState.MATCH_END)
	match_ended.emit(allied_score, enemy_score)

# --- Defense phase (V1 automated) ---

func _resolve_defense_phase() -> void:
	var enemy_offense: float = EnemyTeam.get_combined_offensive_rating()
	var allied_defense: float = AlliedTeam.get_combined_defensive_rating()
	var stamina_factor: float = AlliedTeam.get_avg_stamina_pct()
	var threshold: float = (enemy_offense - allied_defense * stamina_factor) / 100.0
	threshold = clamp(threshold, 0.1, 0.9)
	print("[DEFENSE] Q%d — enemy offense %.0f vs allied defense %.0f (stamina %.0f%%) → %.0f%% enemy score chance" % [
		current_quarter, enemy_offense, allied_defense,
		stamina_factor * 100, threshold * 100])
	if randf() < threshold:
		var points: int = 3 if randf() > 0.7 else 2
		enemy_score += points
		print("[DEFENSE] Enemy scores %d! Allied %d : Enemy %d" % [points, allied_score, enemy_score])
		score_changed.emit(allied_score, enemy_score)
	else:
		print("[DEFENSE] Allied defense holds!")
	end_possession()

# --- Baller reset between possessions ---

func _reset_ballers_for_next_possession() -> void:
	for b in AlliedTeam.get_active_ballers():
		b.is_exhausted = false
		b.current_stamina = b.stats.max_stamina
		b.consecutive_actions = 0
		b.acted_this_beat = false
		b.is_in_motion = false
		# Hype does NOT reset between possessions
	for b in EnemyTeam.get_active_ballers():
		b.current_stamina = b.stats.max_stamina
		b.is_exhausted = false
		b.consecutive_actions = 0
		b.acted_this_beat = false
