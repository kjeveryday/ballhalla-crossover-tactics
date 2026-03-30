extends Node2D
# TestEnemyPlacement — Step 10 acceptance criteria
#
#   1. 5 enemy ballers render at correct starting positions
#   2. Shot % is visibly lower when enemy is adjacent to shooter
#   3. Enemy ballers do not move after a beat end

const EXPECTED_POSITIONS: Array = [
	[4, 5],  # PG Guard
	[2, 5],  # SG Guard
	[4, 3],  # SF Forward
	[2, 2],  # PF Forward
	[4, 1],  # C Center
]

var shooter: Node = null

func _ready() -> void:
	EnemyFormation.spawn_defense(self)
	_spawn_shooter()
	print("=== TestEnemyPlacement: Step 10 Acceptance Criteria ===")
	_run_tests()
	print("=== Done ===")

func _spawn_shooter() -> void:
	AlliedTeam.clear()
	var scene: PackedScene = preload("res://entities/baller/AlliedBaller.tscn")
	shooter = scene.instantiate()
	shooter.set("stats", load("res://resources/stats/allied/sf_remix.tres"))
	add_child(shooter)
	shooter.place_on_grid(4, 5)
	shooter.has_ball = true
	# AlliedBaller._ready() already registers — but clear was called after instantiate
	# so re-register manually here
	AlliedTeam.register(shooter)

func _run_tests() -> void:
	_test_enemy_count()
	_test_enemy_positions()
	_test_shot_penalty_applies()
	_test_enemies_do_not_move()

# --- Test 1: 5 enemies spawned ---

func _test_enemy_count() -> void:
	var count: int = EnemyTeam.get_active_ballers().size()
	_assert(count == 5, "5 enemy ballers spawned", 5, count)

# --- Test 2: Positions match 2-3 zone formation ---

func _test_enemy_positions() -> void:
	var enemies: Array = EnemyTeam.get_active_ballers()
	var pos_labels: Array = ["PG Guard", "SG Guard", "SF Forward", "PF Forward", "C Center"]
	for i in range(EXPECTED_POSITIONS.size()):
		var expected_col: int = EXPECTED_POSITIONS[i][0]
		var expected_row: int = EXPECTED_POSITIONS[i][1]
		# Find the enemy at this position
		var found: bool = false
		for e in enemies:
			if e.grid_col == expected_col and e.grid_row == expected_row:
				found = true
				break
		_assert(found, "%s at (%d, %d)" % [pos_labels[i], expected_col, expected_row])

# --- Test 3: Shot % lower with adjacent enemy ---

func _test_shot_penalty_applies() -> void:
	# Shooter at (4,5) — PG Guard also at (4,5) which is distance 0 (same cell)
	# Place shooter at (4,4) so PG Guard at (4,5) is adjacent (dist 1)
	shooter.place_on_grid(4, 4)
	var mod_adjacent: float = ShotSystem._get_defense_modifier(shooter)
	_assert(mod_adjacent < 0.0, "Shot modifier is negative with adjacent enemy (%.2f)" % mod_adjacent)
	print("  Shot modifier with adjacent enemy: %.2f (%.0f%%)" % [mod_adjacent, mod_adjacent * 100])

	# Move shooter far away — no defenders nearby
	shooter.place_on_grid(4, 11)
	var mod_clear: float = ShotSystem._get_defense_modifier(shooter)
	_assert(mod_clear == 0.0, "No shot modifier when shooter is far from all enemies", 0.0, mod_clear)

# --- Test 4: Enemies do not move after beat end ---

func _test_enemies_do_not_move() -> void:
	var positions_before: Array = []
	for e in EnemyTeam.get_active_ballers():
		positions_before.append(Vector2i(e.grid_col, e.grid_row))

	BeatManager.start_possession()
	BeatManager.end_beat_early()  # Triggers beat end resolution

	var moved: bool = false
	var enemies: Array = EnemyTeam.get_active_ballers()
	for i in range(enemies.size()):
		if Vector2i(enemies[i].grid_col, enemies[i].grid_row) != positions_before[i]:
			moved = true
			break

	_assert(not moved, "Enemy ballers do not move after beat end (Step 11)")

# --- Helper ---

func _assert(condition: bool, label: String, expected = null, actual = null) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		if expected != null:
			print("[FAIL] %s — expected %s, got %s" % [label, str(expected), str(actual)])
		else:
			print("[FAIL] %s" % label)
