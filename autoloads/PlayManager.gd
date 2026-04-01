extends Node
# PlayManager — Autoload
# Play call sequencing, bonus triggers, and per-beat expiry.
# Plays must be called first in the beat (before any baller actions).

# --- PlayCard inner class ---
class PlayCard:
	var play_name: String = ""
	var required_sequence: Array = []
	var bonus_effect: String = ""
	func _init(name: String, seq: Array, bonus: String) -> void:
		play_name = name
		required_sequence = seq
		bonus_effect = bonus

# --- Starter playbook ---
var PLAYBOOK: Dictionary = {}

# --- State ---
var active_play: PlayCard = null
var sequence_progress: Array = []

# Temporary shot/stamina bonuses applied by play triggers — consumed on use
var pending_shot_bonus: float = 0.0       # Added to next shot pct
var pending_shot_no_stamina: bool = false  # Next shot costs 0 stamina
var iso_baller = null                      # Baller marked by ISO play

signal play_called(play_name: String)
signal play_triggered(play_name: String)
signal play_expired(play_name: String)

func _ready() -> void:
	_build_playbook()

func _build_playbook() -> void:
	PLAYBOOK["pick_and_roll"]  = PlayCard.new("Pick and Roll",  ["screen", "cut", "pass"],  "shot_plus_15")
	PLAYBOOK["give_and_go"]    = PlayCard.new("Give and Go",    ["pass", "cut", "pass"],     "hype_cutter_10")
	PLAYBOOK["iso"]            = PlayCard.new("ISO",            ["iso", "move"],             "iso_shot_plus_20")
	PLAYBOOK["drive_and_kick"] = PlayCard.new("Drive and Kick", ["move", "pass"],            "kick_shot_plus_10")

func call_play(play_key: String) -> void:
	if not PLAYBOOK.has(play_key):
		print("[PLAY] Unknown play: %s" % play_key)
		return
	active_play = PLAYBOOK[play_key]
	sequence_progress.clear()
	print("[PLAY] Coach calls '%s' — sequence: %s" % [
		active_play.play_name, str(active_play.required_sequence)])
	play_called.emit(active_play.play_name)

# Called after every action resolves.
func on_action_resolved(action_type: String) -> void:
	if active_play == null:
		return
	sequence_progress.append(action_type)
	if _sequence_matches():
		_trigger_bonus()
		active_play = null
		sequence_progress.clear()
	elif _sequence_broken():
		print("[PLAY] '%s' broken by '%s' — expired" % [active_play.play_name, action_type])
		play_expired.emit(active_play.play_name)
		active_play = null
		sequence_progress.clear()

func expire_active_play() -> void:
	if active_play != null:
		print("[PLAY] '%s' expired — beat ended before sequence completed" % active_play.play_name)
		play_expired.emit(active_play.play_name)
		active_play = null
		sequence_progress.clear()

# --- Sequence checks ---

func _sequence_matches() -> bool:
	var req: Array = active_play.required_sequence
	if sequence_progress.size() < req.size():
		return false
	var tail: Array = sequence_progress.slice(sequence_progress.size() - req.size())
	return tail == req

func _sequence_broken() -> bool:
	var req: Array = active_play.required_sequence
	for i in range(min(sequence_progress.size(), req.size())):
		if sequence_progress[i] != req[i]:
			return true
	return false

# --- Bonus triggers ---

func _trigger_bonus() -> void:
	print("[PLAY] '%s' TRIGGERED! Bonus: %s" % [active_play.play_name, active_play.bonus_effect])
	play_triggered.emit(active_play.play_name)
	match active_play.bonus_effect:
		"shot_plus_15":
			pending_shot_bonus += 0.15
			print("[PLAY] +15%% shooting bonus on next shot")
		"hype_cutter_10":
			# Grant +10 hype to the baller who just made the cut (last move action)
			var cutter: Node = _find_last_mover()
			if cutter:
				HypeManager.gain_hype(cutter, 10.0)
				print("[PLAY] Give and Go: %s +10 hype" % cutter.stats.display_name)
		"iso_shot_plus_20":
			pending_shot_bonus += 0.20
			# Nearby enemies already lost stamina via ISO talk — bonus pct stacks
			print("[PLAY] +20%% shooting bonus on next shot (ISO)")
		"kick_shot_plus_10":
			pending_shot_bonus += 0.10
			pending_shot_no_stamina = true
			print("[PLAY] +10%% shooting bonus + free shot stamina (Drive and Kick)")

func consume_shot_bonus() -> float:
	var bonus: float = pending_shot_bonus
	pending_shot_bonus = 0.0
	return bonus

func consume_no_stamina_shot() -> bool:
	var val: bool = pending_shot_no_stamina
	pending_shot_no_stamina = false
	return val

# Find the most recently registered allied baller who is in motion or just moved.
func _find_last_mover():
	for b in AlliedTeam.get_active_ballers():
		if b.is_in_motion or b.acted_this_beat:
			return b
	return null
