extends Node
# HypeManager — Autoload
# Hype gain/drain, last-beat bonus, team hype scoring multiplier.

signal hype_changed(baller: Node, delta: int)
signal hype_milestone(level: int)

# Milestone thresholds — reset each possession so they only trigger once per possession.
var _milestone_triggered: Dictionary = {
	100: false, 200: false, 300: false, 400: false, 500: false
}

func _ready() -> void:
	# Last-beat bonus: any action taken in beat 8 gives entire team +15 hype
	BeatManager.action_committed.connect(_on_action_committed)
	BeatManager.possession_ended.connect(_reset_milestones)

func _on_action_committed(_action_type: String) -> void:
	if BeatManager.current_beat == BeatManager.BEATS_PER_POSSESSION:
		print("[HYPE] Last beat! Entire team +15 hype")
		for b in AlliedTeam.get_active_ballers():
			gain_hype(b, 15.0)

# float input is accepted for caller convenience; scaled by hype_charge_rate then rounded to int before storage and signal emission.
func gain_hype(baller: Node, base_amount: float) -> void:
	var rate: float = 1.0 + baller.stats.hype_charge_rate
	var gained: int = roundi(base_amount * rate)
	baller.current_hype = min(100, baller.current_hype + gained)
	hype_changed.emit(baller, gained)
	print("[HYPE] %s +%d → %d" % [baller.stats.display_name, gained, baller.current_hype])
	_check_milestones()

# float input is accepted for caller convenience; value is rounded to int before storage and signal emission.
func drain_hype(baller: Node, amount: float) -> void:
	var drained: int = roundi(amount)
	baller.current_hype = max(0, baller.current_hype - drained)
	hype_changed.emit(baller, -drained)
	print("[HYPE] %s -%d → %d" % [baller.stats.display_name, drained, baller.current_hype])

func get_team_hype() -> int:
	var total: int = 0
	for b in AlliedTeam.get_active_ballers():
		total += b.current_hype
	return total  # Max 500 (5 × 100)

# Returns base_points + 1 bonus if team hype >= 80% (400 of 500).
func compute_shot_value(base_points: int) -> int:
	var team_hype_pct: float = get_team_hype() / 500.0
	var bonus: int = 1 if team_hype_pct >= 0.8 else 0
	if bonus > 0:
		print("[HYPE] Team hype %.0f%% — +1 bonus point!" % (team_hype_pct * 100))
	return base_points + bonus

# Called when an enemy steal attempt fails (ball carrier gets +8 hype).
func on_steal_failed(ball_carrier: Node) -> void:
	gain_hype(ball_carrier, 8.0)

func _check_milestones() -> void:
	var total: int = get_team_hype()
	for threshold in _milestone_triggered.keys():
		if total >= threshold and not _milestone_triggered[threshold]:
			_milestone_triggered[threshold] = true
			hype_milestone.emit(threshold)
			print("[HYPE] Milestone reached: %d!" % threshold)
			break  # Only one milestone per gain call

func _reset_milestones() -> void:
	for key in _milestone_triggered.keys():
		_milestone_triggered[key] = false
