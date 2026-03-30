extends Node
# ShotSystem — Autoload
# Zone-based shot resolution, defense modifier, rebound.
# Scoring tallied here until QuarterManager takes over in Step 14.

const DEEP_PENALTY: float = 0.16

# Temporary score tracking — QuarterManager replaces this in Step 14.
var allied_score: int = 0

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
	var defense_mod: float = _get_defense_modifier(shooter)
	var final_pct: float = clamp(base_pct + defense_mod, 0.05, 0.95)

	print("[SHOT] %s shooting from %s — base %.0f%% defense %+.0f%% final %.0f%%" % [
		shooter.stats.display_name,
		GridManager.CourtZone.keys()[zone],
		base_pct * 100, defense_mod * 100, final_pct * 100
	])

	shooter.acted_this_beat = true
	StaminaSystem.record_action(shooter)
	BeatManager.spend_action("shoot")
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
	var points: int = 3 if zone >= GridManager.CourtZone.THREE_POINT else 2
	allied_score += points
	shooter.has_ball = false
	HypeManager.gain_hype(shooter, 20.0)
	print("[SHOT] MADE! +%d pts — allied score: %d" % [points, allied_score])
	shot_made.emit(shooter, points)
	# Possession ends — QuarterManager handles full flow in Step 14
	GameStateMachine.transition_to(GameStateMachine.BattleState.OFFENSE_START)

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
		# Full possession-end flow in Step 14
		GameStateMachine.transition_to(GameStateMachine.BattleState.OFFENSE_START)

func _find_best_rebounder() -> Node:
	var best: Node = null
	var best_rating: int = -1
	for b in AlliedTeam.get_active_ballers():
		if not b.is_exhausted and b.stats.rebound_rating > best_rating:
			best_rating = b.stats.rebound_rating
			best = b
	return best
