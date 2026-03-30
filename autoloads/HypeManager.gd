extends Node
# HypeManager — Autoload stub
# Full hype gain triggers, team hype multiplier, and gravity integration wired in Step 12.

signal hype_changed(baller)

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
