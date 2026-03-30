extends Node
# AbilitySystem — Autoload
# V1 abilities: Move, Pass, End Turn.
# V2 abilities (Screen, Talk) added in Step 13.

# Move speed modifiers by position index (PG=0, SG=1, SF=2, PF=3, C=4)
const SPEED_MODIFIERS: Array = [2, 2, 0, -2, -2]

func get_move_range(baller: Node) -> int:
	var pos_idx: int = baller.stats.position
	return 4 + SPEED_MODIFIERS[pos_idx]

# --- Move ---

func initiate_move(baller: Node, destination: Vector2i) -> void:
	if not baller.can_act():
		print("[ABILITY] %s cannot act (exhausted)" % baller.stats.display_name)
		return
	var cost: int = StaminaSystem.get_stamina_cost(baller, 10)
	baller.drain_stamina(cost)
	baller.move_destination = destination
	baller.is_in_motion = true
	baller.acted_this_beat = true
	StaminaSystem.record_action(baller)
	BeatManager.spend_action("move")
	# First step resolves immediately as part of this action
	MovementSystem.continue_movement(baller)
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
	from_baller.drain_stamina(cost)
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
		PlayManager.on_action_resolved("pass")
		print("[PASS] %s → %s" % [from_baller.stats.display_name, to_baller.stats.display_name])
	BeatManager.action_resolved.emit()

# --- Shoot ---

func attempt_shot(shooter: Node) -> void:
	ShotSystem.attempt_shot(shooter)

# --- End Turn ---

func end_turn(baller: Node) -> void:
	baller.acted_this_beat = true
	BeatManager.spend_action("end_turn")
	print("[ACTION] %s ended turn" % baller.stats.display_name)
	BeatManager.action_resolved.emit()

# --- Internal ---

func _handle_turnover(baller: Node) -> void:
	baller.has_ball = false
	print("[TURNOVER] %s — possession ends (full resolution in Step 14)" % baller.stats.display_name)
