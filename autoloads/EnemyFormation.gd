extends Node
# EnemyFormation — Autoload
# Spawns and places the 5 Hollywood enemy ballers in the hardcoded 2-3 zone defense.
# No movement yet — static obstacles for shot penalty purposes.
# Full AI movement and guard assignments wired in Step 11.

# 2-3 zone starting formation: [col, row, stats_path]
const FORMATION: Array = [
	[4, 5, "res://resources/stats/enemy/hollywood_pg.tres"],  # PG Guard
	[2, 5, "res://resources/stats/enemy/hollywood_sg.tres"],  # SG Guard
	[4, 3, "res://resources/stats/enemy/hollywood_sf.tres"],  # SF Forward
	[2, 2, "res://resources/stats/enemy/hollywood_pf.tres"],  # PF Forward
	[4, 1, "res://resources/stats/enemy/hollywood_c.tres"],   # C Center
]

var _enemy_scene: PackedScene = preload("res://entities/baller/EnemyBaller.tscn")
var spawned: Array = []

# Spawns the 5 enemy ballers as children of parent_node.
# Clears any previously spawned enemies first.
func spawn_defense(parent_node: Node) -> void:
	despawn()
	EnemyTeam.clear()
	for entry in FORMATION:
		var b: Node = _enemy_scene.instantiate()
		b.set("stats", load(entry[2]))
		parent_node.add_child(b)
		b.place_on_grid(entry[0], entry[1])
		spawned.append(b)
	print("[FORMATION] 2-3 zone defense spawned (%d ballers)" % spawned.size())

func despawn() -> void:
	for b in spawned:
		if is_instance_valid(b):
			b.queue_free()
	spawned.clear()
