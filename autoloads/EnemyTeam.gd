extends Node
# EnemyTeam — Autoload
# Registry for all enemy Baller nodes. Full AI behavior wired in Step 11.

var ballers: Array = []

func register(baller: Node) -> void:
	if not ballers.has(baller):
		ballers.append(baller)

func unregister(baller: Node) -> void:
	ballers.erase(baller)

func get_active_ballers() -> Array:
	var result: Array = []
	for b in ballers:
		if b.is_active:
			result.append(b)
	return result

func get_combined_offensive_rating() -> float:
	var total: float = 0.0
	for b in get_active_ballers():
		total += b.stats.offensive_rating
	return total

func clear() -> void:
	ballers.clear()
