extends Node
# AlliedTeam — Autoload
# Registry for all allied Baller nodes. Other systems call get_active_ballers()
# rather than walking the scene tree.

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

func get_ball_carrier():
	for b in ballers:
		if b.has_ball:
			return b
	return null

func get_combined_defensive_rating() -> float:
	var total: float = 0.0
	for b in get_active_ballers():
		total += b.stats.defensive_rating
	return total

func get_avg_stamina_pct() -> float:
	var active: Array = get_active_ballers()
	if active.is_empty():
		return 1.0
	var total: float = 0.0
	for b in active:
		total += float(b.current_stamina) / float(b.stats.max_stamina)
	return total / active.size()

func clear() -> void:
	ballers.clear()
