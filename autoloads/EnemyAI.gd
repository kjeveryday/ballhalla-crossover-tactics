extends Node
# EnemyAI — Autoload
# Guard initialization, per-beat movement, and per-beat action resolution.
# Wired into BeatManager beat end sequence (steps ⑥ and ⑦).

# --- Guard Assignments ---

# Called at OFFENSE_START. Assigns one enemy to guard each allied baller 1:1.
func initialize_assignments() -> void:
	var allied: Array = AlliedTeam.get_active_ballers()
	var enemies: Array = EnemyTeam.get_active_ballers()
	for i in range(min(allied.size(), enemies.size())):
		enemies[i].guard_assignment = allied[i]
		print("[AI] %s guards %s" % [
			enemies[i].stats.display_name, allied[i].stats.display_name])

# --- Enemy Movement (beat step ⑥) ---

func update_enemy_movement() -> void:
	# Decrement screen recovery timers — re-assign guard when timer expires
	for b in AlliedTeam.get_active_ballers():
		if b.screen_recovery_timer > 0:
			b.screen_recovery_timer -= 1
			if b.screen_recovery_timer == 0:
				_reassign_unguarded(b)
	for enemy in EnemyTeam.get_active_ballers():
		var target: Node = enemy.guard_assignment
		if target == null or not target.is_active:
			target = _find_ball_carrier()
		if target == null:
			continue
		var dist: int = _chebyshev(enemy, target)
		var steps: int = _get_aggression_steps(target)
		var taken: int = 0
		while taken < steps and dist > 1:
			_move_one_step_toward(enemy, target)
			dist = _chebyshev(enemy, target)
			taken += 1

func _get_aggression_steps(target: Node) -> int:
	var hype_pct: float = HypeManager.get_team_hype() / 500.0
	var gravity: int = GravitySystem.compute_gravity(target)
	var base: int = 1
	if hype_pct > 0.6:
		base += 1  # High allied hype = faster close-out
	if gravity >= GravitySystem.DOUBLE_TEAM_GRAVITY_THRESHOLD:
		base += 1  # High gravity = extra step
	return base

func _move_one_step_toward(enemy: Node, target: Node) -> void:
	var dc: int = target.grid_col - enemy.grid_col
	var dr: int = target.grid_row - enemy.grid_row
	var next_col: int = enemy.grid_col
	var next_row: int = enemy.grid_row
	if abs(dc) >= abs(dr):
		next_col += sign(dc)
	else:
		next_row += sign(dr)
	if GridManager.get_cell(next_col, next_row) != null:
		enemy.place_on_grid(next_col, next_row)

func _reassign_unguarded(target: Node) -> void:
	for enemy in EnemyTeam.get_active_ballers():
		if enemy.guard_assignment == null:
			enemy.guard_assignment = target
			print("[AI] %s re-assigned to guard %s (screen expired)" % [
				enemy.stats.display_name, target.stats.display_name])
			break

# --- Enemy Actions (beat step ⑦) ---

func resolve_enemy_actions() -> void:
	for enemy in EnemyTeam.get_active_ballers():
		var num: int = _roll_action_count()
		for _i in range(num):
			_perform_action(enemy)

func _roll_action_count() -> int:
	var hype_pct: float = HypeManager.get_team_hype() / 500.0
	var roll: float = randf()
	if hype_pct < 0.3:
		if roll < 0.4: return 0
		if roll < 0.8: return 1
		return 2
	elif hype_pct < 0.7:
		if roll < 0.1: return 0
		if roll < 0.5: return 1
		if roll < 0.85: return 2
		return 3
	else:
		if roll < 0.1: return 1
		if roll < 0.5: return 2
		return 3

func _perform_action(enemy: Node) -> void:
	var available: Array = _get_available_actions(enemy)
	if available.is_empty():
		return
	var chosen: String = available[randi() % available.size()]
	match chosen:
		"foul":
			var t: Node = _get_foul_target(enemy)
			if t:
				t.drain_stamina(8)
				print("[AI] %s fouls %s (-8 stamina)" % [
					enemy.stats.display_name, t.stats.display_name])
		"grab":
			var t: Node = _get_grab_target(enemy)
			if t:
				t.beats_to_destination += 1
				print("[AI] %s grabs %s (+1 beat delay)" % [
					enemy.stats.display_name, t.stats.display_name])
		"trash_talk":
			var t: Node = _get_trash_talk_target(enemy)
			if t:
				HypeManager.drain_hype(t, 10.0)
				print("[AI] %s trash talks %s (-10 hype)" % [
					enemy.stats.display_name, t.stats.display_name])

func _get_available_actions(enemy: Node) -> Array:
	var actions: Array = []
	var adjacent: Array = AlliedTeam.get_active_ballers().filter(
		func(b): return _chebyshev(enemy, b) <= 1)

	if not adjacent.is_empty():
		actions.append("foul")

	var moving: Array = adjacent.filter(func(b): return b.is_in_motion)
	if not moving.is_empty():
		actions.append("grab")

	var hype_targets: Array = AlliedTeam.get_active_ballers().filter(
		func(b): return _chebyshev(enemy, b) <= 3 and b.current_hype > 10)
	if not hype_targets.is_empty():
		actions.append("trash_talk")

	return actions

func _get_foul_target(enemy: Node):
	var adjacent: Array = AlliedTeam.get_active_ballers().filter(
		func(b): return _chebyshev(enemy, b) <= 1)
	for b in adjacent:
		if b.has_ball:
			return b
	return adjacent[0] if not adjacent.is_empty() else null

func _get_grab_target(enemy: Node):
	var moving: Array = AlliedTeam.get_active_ballers().filter(
		func(b): return b.is_in_motion and _chebyshev(enemy, b) <= 1)
	return moving[0] if not moving.is_empty() else null

func _get_trash_talk_target(enemy: Node):
	var in_range: Array = AlliedTeam.get_active_ballers().filter(
		func(b): return _chebyshev(enemy, b) <= 3 and b.current_hype > 10)
	if in_range.is_empty():
		return null
	in_range.sort_custom(func(a, b): return a.current_hype > b.current_hype)
	return in_range[0]

# --- Helpers ---

func _chebyshev(a: Node, b: Node) -> int:
	return GridManager.chebyshev_distance(a.grid_col, a.grid_row, b.grid_col, b.grid_row)

func _find_ball_carrier():
	return AlliedTeam.get_ball_carrier()
