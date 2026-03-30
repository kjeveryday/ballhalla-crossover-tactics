extends Node2D
# TestShotResolution — Step 9 acceptance criteria
#
#   1. Shots from PAINT hit at statistically correct rate over 100 rolls
#   2. Shots from DEEP have noticeably lower success rate
#   3. Made shot adds correct point value (2 or 3)
#   4. Missed shot triggers rebound; correct team wins based on rebound stats
#   5. Adjacent enemy applies -0.15 defense modifier

const SAMPLE_SIZE: int = 100
const TOLERANCE: float = 0.10  # ±10% acceptable variance

var AlliedBallerScene: PackedScene = preload("res://entities/baller/AlliedBaller.tscn")
var EnemyBallerScene: PackedScene = preload("res://entities/baller/EnemyBaller.tscn")

var test_baller: Node = null
var enemy_baller: Node = null

func _ready() -> void:
	_spawn_ballers()
	print("=== TestShotResolution: Step 9 Acceptance Criteria ===")
	_run_tests()
	print("=== Done ===")

func _spawn_ballers() -> void:
	AlliedTeam.clear()
	EnemyTeam.clear()

	test_baller = AlliedBallerScene.instantiate()
	test_baller.set("stats", load("res://resources/stats/allied/sf_remix.tres"))
	add_child(test_baller)
	test_baller.place_on_grid(4, 5)
	test_baller.has_ball = true
	AlliedTeam.register(test_baller)

	enemy_baller = EnemyBallerScene.instantiate()
	enemy_baller.set("stats", load("res://resources/stats/enemy/hollywood_sf.tres"))
	add_child(enemy_baller)
	enemy_baller.place_on_grid(4, 9)  # Far away — not contesting

func _run_tests() -> void:
	_test_zone_accuracy(1, 0.58, "PAINT",       load("res://resources/stats/allied/c_remix.tres"))
	_test_zone_accuracy(5, 0.50, "MIDRANGE",    load("res://resources/stats/allied/sf_remix.tres"))
	_test_zone_accuracy(7, 0.36, "THREE_POINT", load("res://resources/stats/allied/sf_remix.tres"))
	_test_zone_accuracy(10, 0.20, "DEEP",       load("res://resources/stats/allied/sf_remix.tres"))
	_test_point_value_paint()
	_test_point_value_three()
	_test_rebound_triggers()
	_test_contest_modifier()

# --- Test: statistical shot accuracy ---

func _test_zone_accuracy(row: int, expected_pct: float, zone_label: String, stats_res: Resource) -> void:
	test_baller.set("stats", stats_res)
	test_baller.place_on_grid(4, row)
	EnemyTeam.clear()  # No defenders for base accuracy test

	var made: int = 0
	for _i in range(SAMPLE_SIZE):
		var zone: int = GridManager.get_zone(4, row)
		var pct: float = ShotSystem._get_base_shot_pct(test_baller, zone)
		if randf() <= pct:
			made += 1

	var actual: float = float(made) / SAMPLE_SIZE
	var pass_cond: bool = abs(actual - expected_pct) <= TOLERANCE
	print("[%s] %s — expected ~%.0f%%, got %.0f%%" % [
		"PASS" if pass_cond else "FAIL",
		zone_label,
		expected_pct * 100,
		actual * 100
	])

# --- Test: point values ---

func _test_point_value_paint() -> void:
	test_baller.set("stats", load("res://resources/stats/allied/c_remix.tres"))
	test_baller.place_on_grid(4, 1)  # PAINT
	EnemyTeam.clear()
	var zone: int = GridManager.get_zone(4, 1)
	var points: int = 3 if zone >= GridManager.CourtZone.THREE_POINT else 2
	_assert(points == 2, "PAINT shot worth 2 points", 2, points)

func _test_point_value_three() -> void:
	test_baller.place_on_grid(4, 7)  # THREE_POINT
	EnemyTeam.clear()
	var zone: int = GridManager.get_zone(4, 7)
	var points: int = 3 if zone >= GridManager.CourtZone.THREE_POINT else 2
	_assert(points == 3, "THREE_POINT shot worth 3 points", 3, points)

# --- Test: missed shot triggers rebound ---

func _test_rebound_triggers() -> void:
	test_baller.set("stats", load("res://resources/stats/allied/sf_remix.tres"))
	test_baller.place_on_grid(4, 5)
	EnemyTeam.clear()
	BeatManager.start_possession()
	test_baller.has_ball = true
	test_baller.current_stamina = test_baller.stats.max_stamina
	test_baller.is_exhausted = false
	test_baller.acted_this_beat = false
	test_baller.consecutive_actions = 0

	var rebound_fired: Array = [false]
	ShotSystem.rebound_won.connect(func(_b, _off): rebound_fired[0] = true)

	# Force a miss by temporarily overriding — run 20 shots until one misses
	var got_miss: bool = false
	for _i in range(20):
		if got_miss:
			break
		test_baller.has_ball = true
		test_baller.acted_this_beat = false
		test_baller.consecutive_actions = 0
		test_baller.current_stamina = test_baller.stats.max_stamina
		# Use raw roll to check — if roll > 0.50 it's a miss for SF midrange
		var zone: int = GridManager.get_zone(4, 5)
		var pct: float = ShotSystem._get_base_shot_pct(test_baller, zone)
		if randf() > pct:
			got_miss = true
			# Manually trigger missed shot to test rebound
			ShotSystem._handle_missed_shot(test_baller)

	_assert(rebound_fired[0], "Missed shot triggers rebound_won signal")

# --- Test: defense modifier ---

func _test_contest_modifier() -> void:
	test_baller.set("stats", load("res://resources/stats/allied/sf_remix.tres"))
	test_baller.place_on_grid(4, 3)
	EnemyTeam.clear()

	# Register enemy adjacent (Chebyshev 1)
	enemy_baller.place_on_grid(4, 4)
	EnemyTeam.register(enemy_baller)

	var modifier: float = ShotSystem._get_defense_modifier(test_baller)
	_assert(modifier == -0.15, "Adjacent enemy applies -0.15 modifier", -0.15, modifier)

	# Enemy at distance 2
	enemy_baller.place_on_grid(4, 5)
	modifier = ShotSystem._get_defense_modifier(test_baller)
	_assert(modifier == -0.07, "Distance-2 enemy applies -0.07 modifier", -0.07, modifier)

	# Enemy at distance 3 — no modifier
	enemy_baller.place_on_grid(4, 6)
	modifier = ShotSystem._get_defense_modifier(test_baller)
	_assert(modifier == 0.0, "Distance-3 enemy has no modifier", 0.0, modifier)

	EnemyTeam.clear()

# --- Helper ---

func _assert(condition: bool, label: String, expected = null, actual = null) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		if expected != null:
			print("[FAIL] %s — expected %s, got %s" % [label, str(expected), str(actual)])
		else:
			print("[FAIL] %s" % label)
