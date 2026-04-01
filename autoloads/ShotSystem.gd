extends Node
# ShotSystem — Autoload
# Zone-based shot resolution, defense modifier, rebound.
# Scoring tallied here until QuarterManager takes over in Step 14.

const DEEP_PENALTY: float = 0.16

signal shot_made(shooter, points: int)
signal shot_missed(shooter)
signal rebound_won(baller, is_offensive: bool)

func attempt_shot(shooter: Node) -> void:
	if not shooter.can_act():
		print("[SHOT] %s cannot act" % shooter.stats.display_name)
		return
	if not shooter.has_ball:
		print("[SHOT] %s does not have the ball" % shooter.stats.display_name)
		return

	var zone: int = GridManager.get_zone(shooter.grid_col, shooter.grid_row)
	var base_pct: float = _get_base_shot_pct(shooter, zone)
	var play_bonus: float = PlayManager.consume_shot_bonus()
	var no_stamina: bool = PlayManager.consume_no_stamina_shot()
	var defense_mod: float = _get_defense_modifier(shooter)
	var final_pct: float = clamp(base_pct + defense_mod + play_bonus, 0.05, 0.95)

	print("[SHOT] %s shooting from %s — base %.0f%% defense %+.0f%% play +%.0f%% final %.0f%%%s" % [
		shooter.stats.display_name,
		GridManager.CourtZone.keys()[zone],
		base_pct * 100, defense_mod * 100, play_bonus * 100, final_pct * 100,
		" (free stamina)" if no_stamina else ""
	])

	shooter.acted_this_beat = true
	if not no_stamina:
		var shot_cost: int = StaminaSystem.get_stamina_cost(shooter, 10)
		shooter.drain_stamina(shot_cost)
	StaminaSystem.record_action(shooter)
	BeatManager.spend_action("shoot")
	PlayManager.on_action_resolved("shoot")
	GameStateMachine.transition_to(GameStateMachine.BattleState.SHOT_RESOLVING)

	var roll: float = randf()
	if roll <= final_pct:
		_handle_made_shot(shooter, zone)
	else:
		_handle_missed_shot(shooter)

	BeatManager.action_resolved.emit()

# --- Shot percentage ---

func _get_base_shot_pct(shooter: Node, zone: int) -> float:
	match zone:
		GridManager.CourtZone.PAINT:
			return shooter.stats.shooting_2pt
		GridManager.CourtZone.MIDRANGE:
			return shooter.stats.shooting_2pt
		GridManager.CourtZone.THREE_POINT:
			return shooter.stats.shooting_3pt
		GridManager.CourtZone.DEEP:
			return max(0.05, shooter.stats.shooting_3pt - DEEP_PENALTY)
	return 0.0

# --- Defense modifier (Chebyshev proximity) ---

func _get_defense_modifier(shooter: Node) -> float:
	var penalty: float = 0.0
	for enemy in EnemyTeam.get_active_ballers():
		var dist: int = max(
			abs(enemy.grid_col - shooter.grid_col),
			abs(enemy.grid_row - shooter.grid_row)
		)
		if dist <= 1:
			penalty -= 0.15
		elif dist == 2:
			penalty -= 0.07
	return penalty

# --- Outcomes ---

func _handle_made_shot(shooter: Node, zone: int) -> void:
	var base_points: int = 3 if zone >= GridManager.CourtZone.THREE_POINT else 2
	var points: int = HypeManager.compute_shot_value(base_points)
	shooter.has_ball = false
	HypeManager.gain_hype(shooter, 20.0)
	print("[SHOT] MADE! +%d pts" % points)
	shot_made.emit(shooter, points)
	QuarterManager.add_allied_score(points)

func _handle_missed_shot(shooter: Node) -> void:
	print("[SHOT] MISSED by %s" % shooter.stats.display_name)
	HypeManager.drain_hype(shooter, 10.0)
	shooter.has_ball = false
	shot_missed.emit(shooter)
	_resolve_rebound(shooter)

func _resolve_rebound(shooter: Node) -> void:
	# Offensive rebound chance: shooter's rebound stat / 15 (C=60%, SF=33%, PG=20%)
	var off_chance: float = clamp(shooter.stats.rebound_rating / 15.0, 0.1, 0.8)
	var roll: float = randf()
	if roll < off_chance:
		# Offensive rebound — find nearest allied baller
		var rebounder: Node = _find_best_rebounder()
		if rebounder != null:
			rebounder.has_ball = true
			HypeManager.gain_hype(rebounder, 10.0)
			print("[REBOUND] Offensive! %s gets the ball" % rebounder.stats.display_name)
			rebound_won.emit(rebounder, true)
			GameStateMachine.transition_to(GameStateMachine.BattleState.SELECTING_BALLER)
	else:
		print("[REBOUND] Defensive — possession ends")
		rebound_won.emit(null, false)
		QuarterManager.end_possession()

func _find_best_rebounder() -> Node:
	var best: Node = null
	var best_rating: int = -1
	for b in AlliedTeam.get_active_ballers():
		if not b.is_exhausted and b.stats.rebound_rating > best_rating:
			best_rating = b.stats.rebound_rating
			best = b
	return best
