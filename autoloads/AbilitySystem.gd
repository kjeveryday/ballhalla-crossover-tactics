extends Node
# AbilitySystem — Autoload
# V1 abilities: Move, Pass, End Turn.
# V2 abilities: Screen, Talk (Trash/Leadership/ISO), Play Call.

# Move speed modifiers by position index (PG=0, SG=1, SF=2, PF=3, C=4)
const SPEED_MODIFIERS: Array = [2, 2, 0, -2, -2]

signal pass_completed(from_pos: Vector2i, to_pos: Vector2i)
signal turnover_occurred(baller: Node)
signal screen_performed(screener: Node)

func get_move_range(baller: Node) -> int:
	var pos_idx: int = baller.stats.position
	return 4 + SPEED_MODIFIERS[pos_idx]

# --- Move ---

func initiate_move(baller: Node, destination: Vector2i) -> void:
	if not baller.can_act():
		print("[ABILITY] %s cannot act (exhausted)" % baller.stats.display_name)
		return
	var cost: int = StaminaSystem.get_stamina_cost(baller, 10)
	StaminaSystem.drain(baller, cost)
	baller.move_destination = destination
	baller.is_in_motion = true
	baller.acted_this_beat = true
	StaminaSystem.record_action(baller)
	BeatManager.spend_action("move")
	# Re-run BFS to guarantee pf_root is fresh regardless of whether show_move_range
	# was called (programmatic moves skip the UI flow and never prime the cache).
	GridManager.mark_reachable_cells(baller.grid_col, baller.grid_row, get_move_range(baller))
	MovementSystem.set_path(baller, GridManager.get_path_to_cell(destination.x, destination.y))
	MovementSystem.continue_movement(baller)
	PlayManager.on_action_resolved("move")
	BeatManager.action_resolved.emit()

# --- Cut ---
# A cut is a burst sprint toward the opponent's basket.
# Costs 5 more stamina than a regular move (15 vs 10), but destination must be toward
# the basket (destination.y < current row). Registers as "cut" for play sequences.

func perform_cut(baller: Node, destination: Vector2i) -> void:
	if not baller.can_act():
		print("[ABILITY] %s cannot act (exhausted)" % baller.stats.display_name)
		return
	if destination.y >= baller.grid_row:
		print("[ABILITY] %s cut destination must be toward the basket (lower row)" % baller.stats.display_name)
		return
	var cost: int = StaminaSystem.get_stamina_cost(baller, 15)
	StaminaSystem.drain(baller, cost)
	baller.move_destination = destination
	baller.is_in_motion = true
	baller.acted_this_beat = true
	StaminaSystem.record_action(baller)
	BeatManager.spend_action("cut")
	GridManager.mark_reachable_cells(baller.grid_col, baller.grid_row, get_move_range(baller))
	MovementSystem.set_path(baller, GridManager.get_path_to_cell(destination.x, destination.y))
	MovementSystem.continue_movement(baller)
	PlayManager.on_action_resolved("cut")
	BeatManager.action_resolved.emit()

# --- Pass ---

func attempt_pass(from_baller: Node, to_baller: Node) -> void:
	if not from_baller.can_act():
		print("[ABILITY] %s cannot act (exhausted)" % from_baller.stats.display_name)
		return
	if not from_baller.has_ball:
		print("[ABILITY] %s does not have the ball" % from_baller.stats.display_name)
		return
	var cost: int = StaminaSystem.get_stamina_cost(from_baller, 10)
	StaminaSystem.drain(from_baller, cost)
	from_baller.acted_this_beat = true
	StaminaSystem.record_action(from_baller)
	BeatManager.spend_action("pass")
	var roll: float = randf()
	if roll < from_baller.stats.turnover_chance:
		_handle_turnover(from_baller)
	else:
		from_baller.has_ball = false
		to_baller.has_ball = true
		HypeManager.gain_hype(from_baller, 5.0)
		pass_completed.emit(from_baller.position, to_baller.position)
		PlayManager.on_action_resolved("pass")
		print("[PASS] %s → %s" % [from_baller.stats.display_name, to_baller.stats.display_name])
	BeatManager.action_resolved.emit()

# --- Shoot ---

func attempt_shot(shooter: Node) -> void:
	ShotSystem.attempt_shot(shooter)

# --- Screen ---

func perform_screen(screener: Node) -> void:
	if not screener.can_act():
		print("[ABILITY] %s cannot act (exhausted)" % screener.stats.display_name)
		return
	var cost: int = StaminaSystem.get_stamina_cost(screener, 10)
	StaminaSystem.drain(screener, cost)
	screener.acted_this_beat = true
	StaminaSystem.record_action(screener)
	# Nullify guard assignment for the enemy guarding the screener
	for enemy in EnemyTeam.get_active_ballers():
		if enemy.guard_assignment == screener:
			enemy.guard_assignment = null
			print("[SCREEN] %s sets screen — %s loses assignment for 1 beat" % [
				screener.stats.display_name, enemy.stats.display_name])
			break
	screener.screen_recovery_timer = 1
	# +2% shot bonus to nearby teammates
	for b in AlliedTeam.get_active_ballers():
		if b != screener:
			var dist: int = GridManager.chebyshev_distance(
				screener.grid_col, screener.grid_row, b.grid_col, b.grid_row)
			if dist <= 2:
				PlayManager.pending_shot_bonus += 0.02
	screen_performed.emit(screener)
	BeatManager.spend_action("screen")
	PlayManager.on_action_resolved("screen")
	BeatManager.action_resolved.emit()

# --- Talk: Trash ---

func talk_trash(talker: Node) -> void:
	if not talker.can_act():
		print("[ABILITY] %s cannot act (exhausted)" % talker.stats.display_name)
		return
	var cost: int = StaminaSystem.get_stamina_cost(talker, 5)
	StaminaSystem.drain(talker, cost)
	talker.acted_this_beat = true
	StaminaSystem.record_action(talker)
	for enemy in EnemyTeam.get_active_ballers():
		var dist: int = GridManager.chebyshev_distance(
			talker.grid_col, talker.grid_row, enemy.grid_col, enemy.grid_row)
		if dist <= 5:
			StaminaSystem.drain(enemy, 10)
			print("[TALK] %s trash talks %s (-10 stamina)" % [
				talker.stats.display_name, enemy.stats.display_name])
	BeatManager.spend_action("trash_talk")
	PlayManager.on_action_resolved("trash_talk")
	BeatManager.action_resolved.emit()

# --- Talk: Leadership ---

func talk_leadership(talker: Node, ally: Node) -> void:
	if not talker.can_act():
		print("[ABILITY] %s cannot act (exhausted)" % talker.stats.display_name)
		return
	var cost: int = StaminaSystem.get_stamina_cost(talker, 5)
	StaminaSystem.drain(talker, cost)
	talker.acted_this_beat = true
	StaminaSystem.record_action(talker)
	HypeManager.gain_hype(ally, 10.0)
	print("[TALK] %s leadership → %s (+10 hype)" % [
		talker.stats.display_name, ally.stats.display_name])
	BeatManager.spend_action("leadership")
	PlayManager.on_action_resolved("leadership")
	BeatManager.action_resolved.emit()

# --- Talk: ISO ---

func talk_iso(talker: Node) -> void:
	if not talker.can_act():
		print("[ABILITY] %s cannot act (exhausted)" % talker.stats.display_name)
		return
	var cost: int = StaminaSystem.get_stamina_cost(talker, 8)
	StaminaSystem.drain(talker, cost)
	talker.acted_this_beat = true
	StaminaSystem.record_action(talker)
	PlayManager.iso_baller = talker
	for enemy in EnemyTeam.get_active_ballers():
		var dist: int = GridManager.chebyshev_distance(
			talker.grid_col, talker.grid_row, enemy.grid_col, enemy.grid_row)
		if dist <= 3:
			StaminaSystem.drain(enemy, 5)
			print("[TALK] %s ISO staredown → %s (-5 stamina)" % [
				talker.stats.display_name, enemy.stats.display_name])
	BeatManager.spend_action("iso")
	PlayManager.on_action_resolved("iso")
	BeatManager.action_resolved.emit()

# --- Play Call ---

func call_play(play_key: String) -> void:
	if BeatManager.actions_remaining != BeatManager.ACTIONS_PER_BEAT:
		print("[PLAY] Play call must be the first action of the beat")
		return
	PlayManager.call_play(play_key)
	BeatManager.spend_action("play_call")
	BeatManager.action_resolved.emit()

# --- End Turn ---

func end_turn(baller: Node) -> void:
	baller.acted_this_beat = true
	BeatManager.spend_action("end_turn")
	print("[ACTION] %s ended turn" % baller.stats.display_name)
	BeatManager.action_resolved.emit()

# --- Internal ---

func _handle_turnover(baller: Node) -> void:
	baller.has_ball = false
	print("[TURNOVER] %s — possession lost" % baller.stats.display_name)
	turnover_occurred.emit(baller)
	QuarterManager.end_possession()
