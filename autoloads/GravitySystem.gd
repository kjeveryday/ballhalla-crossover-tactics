extends Node
# GravitySystem — Autoload
# Gravity calculation, guard assignments, and double-team trigger logic.
# Gravity is a snapshot taken at beat start — hype earned mid-beat applies next beat.

const DOUBLE_TEAM_GRAVITY_THRESHOLD: int = 7

signal double_team_triggered(target)

func _ready() -> void:
	GameStateMachine.state_changed.connect(_on_state_changed)
	BeatManager.beat_started.connect(_on_beat_started)

func _on_state_changed(_old: int, new_state: int) -> void:
	if new_state == GameStateMachine.BattleState.OFFENSE_START:
		EnemyAI.initialize_assignments()
		check_double_team_triggers()

func _on_beat_started(_beat_num: int) -> void:
	# Refresh each allied baller's cached gravity value at beat start
	for b in AlliedTeam.get_active_ballers():
		b.gravity = compute_gravity(b)

# Gravity = base stat + 1 per 20 hype points
func compute_gravity(baller: Node) -> int:
	var hype_bonus: int = int(baller.current_hype / 20.0)
	return baller.stats.gravity_base + hype_bonus

func check_double_team_triggers() -> void:
	for allied in AlliedTeam.get_active_ballers():
		if compute_gravity(allied) >= DOUBLE_TEAM_GRAVITY_THRESHOLD:
			_try_assign_double_team(allied)

func _try_assign_double_team(target: Node) -> void:
	var already_guarding: Array = EnemyTeam.get_active_ballers().filter(
		func(e): return e.guard_assignment == target)
	if already_guarding.size() >= 2:
		return  # Already double-teamed

	var switcher: Node = _find_switch_candidate(target)
	if switcher:
		switcher.guard_assignment = target
		switcher.drain_stamina(10)
		print("[GRAVITY] Double-team triggered on %s — %s switches" % [
			target.stats.display_name, switcher.stats.display_name])
		double_team_triggered.emit(target)

func _find_switch_candidate(target: Node):
	var candidates: Array = EnemyTeam.get_active_ballers().filter(
		func(e): return e.guard_assignment != target)
	if candidates.is_empty():
		return null
	var t_col: int = target.grid_col
	var t_row: int = target.grid_row
	candidates.sort_custom(func(a, b):
		var da: int = GridManager.chebyshev_distance(a.grid_col, a.grid_row, t_col, t_row)
		var db: int = GridManager.chebyshev_distance(b.grid_col, b.grid_row, t_col, t_row)
		return da < db)
	return candidates[0]
