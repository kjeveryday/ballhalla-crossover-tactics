extends Node
# HypeManager — Autoload
# Hype gain/drain, last-beat bonus, team hype scoring multiplier.

signal hype_changed(baller)

func _ready() -> void:
	# Last-beat bonus: any action taken in beat 8 gives entire team +15 hype
	BeatManager.action_committed.connect(_on_action_committed)

func _on_action_committed(_action_type: String) -> void:
	if BeatManager.current_beat == BeatManager.BEATS_PER_POSSESSION:
		print("[HYPE] Last beat! Entire team +15 hype")
		for b in AlliedTeam.get_active_ballers():
			gain_hype(b, 15.0)

func gain_hype(baller: Node, base_amount: float) -> void:
	var rate: float = 1.0 + baller.stats.hype_charge_rate
	var gained: float = base_amount * rate
	baller.current_hype = min(100.0, baller.current_hype + gained)
	hype_changed.emit(baller)
	print("[HYPE] %s +%.1f → %.1f" % [baller.stats.display_name, gained, baller.current_hype])

func drain_hype(baller: Node, amount: float) -> void:
	baller.current_hype = max(0.0, baller.current_hype - amount)
	hype_changed.emit(baller)
	print("[HYPE] %s -%.1f → %.1f" % [baller.stats.display_name, amount, baller.current_hype])

func get_team_hype() -> float:
	var total: float = 0.0
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
