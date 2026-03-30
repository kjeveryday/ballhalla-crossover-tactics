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

func clear() -> void:
	ballers.clear()
