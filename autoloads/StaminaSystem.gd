extends Node
# StaminaSystem — Autoload
# All stamina math routes through here. No stamina logic lives in Baller directly.

const IDLE_RECOVERY: int = 8
# Ball-hog penalty added on top of base cost depending on consecutive actions
const BALL_HOG_PENALTIES: Array = [0, 5, 15, 30]
# Position stamina bonuses (PG=0, SG=1, SF=2, PF=3, C=4)
const POSITION_STAMINA_BONUS: Array = [0, 0, 1, 2, 3]

func _ready() -> void:
	BeatManager.beat_started.connect(_on_beat_started)

# Reset consecutive_actions for all ballers at the start of each beat.
func _on_beat_started(_beat_num: int) -> void:
	for b in AlliedTeam.get_active_ballers():
		b.consecutive_actions = 0

# Reference formula — max_stamina values in .tres files are pre-computed from this.
# stat_bonus comes from the baller's stats resource; pos_bonus from POSITION_STAMINA_BONUS.
func compute_max_stamina(stat_bonus: int, pos_bonus: int) -> int:
	return 100 + (10 * stat_bonus) + (10 * pos_bonus)

# Returns stamina cost for an action, including ball-hog escalation.
func get_stamina_cost(baller: Node, base_cost: int) -> int:
	var idx: int = min(baller.consecutive_actions, BALL_HOG_PENALTIES.size() - 1)
	var total: int = base_cost + BALL_HOG_PENALTIES[idx]
	if baller.consecutive_actions > 0:
		print("[STAM] %s ball-hog penalty +%d (consecutive: %d) → cost %d" % [
			baller.stats.display_name, BALL_HOG_PENALTIES[idx],
			baller.consecutive_actions, total])
	return total

# Called after every action resolves.
# Increments acting baller's counter; resets everyone else's.
func record_action(acting_baller: Node) -> void:
	for b in AlliedTeam.get_active_ballers():
		if b == acting_baller:
			b.consecutive_actions += 1
		else:
			b.consecutive_actions = 0

# Called by BeatManager at beat end (step ⑦ complete).
# Grants +8 stamina to idle ballers, then clears acted flags.
func apply_idle_recovery() -> void:
	for b in AlliedTeam.get_active_ballers():
		if not b.acted_this_beat and not b.is_exhausted:
			b.heal_stamina(IDLE_RECOVERY)
			print("[STAM] %s idle recovery +%d → %d/%d" % [
				b.stats.display_name, IDLE_RECOVERY,
				b.current_stamina, b.stats.max_stamina])
	# Reset acted flag for next beat
	for b in AlliedTeam.get_active_ballers():
		b.acted_this_beat = false
