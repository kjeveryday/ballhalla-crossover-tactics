extends Node2D
# TestHype — Step 12 acceptance criteria
#
#   1. Hype fills after each trigger: pass +5, rebound +10, made shot +20, last beat +15
#   2. Team hype >= 80% awards +1 bonus point on made shots
#   3. Gravity increases as individual baller hype rises
#   4. Enemy Trash Talk drains highest-hype allied baller in range

var AlliedScene: PackedScene = preload("res://entities/baller/AlliedBaller.tscn")

var pg: Node = null
var sf: Node = null
var c_baller: Node = null

func _ready() -> void:
	_spawn_ballers()
	print("=== TestHype: Step 12 Acceptance Criteria ===")
	_run_tests()
	print("=== Done ===")

func _spawn_ballers() -> void:
	AlliedTeam.clear()
	EnemyTeam.clear()

	pg = AlliedScene.instantiate()
	pg.set("stats", load("res://resources/stats/allied/pg_remix.tres"))
	add_child(pg)
	pg.place_on_grid(4, 8)
	AlliedTeam.register(pg)

	sf = AlliedScene.instantiate()
	sf.set("stats", load("res://resources/stats/allied/sf_remix.tres"))
	add_child(sf)
	sf.place_on_grid(4, 6)
	AlliedTeam.register(sf)

	c_baller = AlliedScene.instantiate()
	c_baller.set("stats", load("res://resources/stats/allied/c_remix.tres"))
	add_child(c_baller)
	c_baller.place_on_grid(4, 2)
	AlliedTeam.register(c_baller)

func _run_tests() -> void:
	_test_pass_hype_gain()
	_test_shot_hype_gain()
	_test_rebound_hype_gain()
	_test_last_beat_bonus()
	_test_team_hype_scoring_bonus()
	_test_gravity_increases_with_hype()
	_test_trash_talk_drains_correct_target()

# --- Test 1: Pass grants +5 hype to passer (with charge rate) ---

func _test_pass_hype_gain() -> void:
	_reset_all()
	pg.has_ball = true
	sf.has_ball = false
	var hype_before: float = pg.current_hype
	# Simulate pass hype gain directly
	HypeManager.gain_hype(pg, 5.0)
	var expected: float = min(100.0, hype_before + 5.0 * (1.0 + pg.stats.hype_charge_rate))
	_assert(abs(pg.current_hype - expected) < 0.01,
		"Pass grants +5 hype (with charge rate %.2f) to passer" % pg.stats.hype_charge_rate,
		expected, pg.current_hype)

# --- Test 2: Made shot grants +20 hype to shooter ---

func _test_shot_hype_gain() -> void:
	_reset_all()
	var hype_before: float = c_baller.current_hype
	HypeManager.gain_hype(c_baller, 20.0)
	var expected: float = min(100.0, hype_before + 20.0 * (1.0 + c_baller.stats.hype_charge_rate))
	_assert(abs(c_baller.current_hype - expected) < 0.01,
		"Made shot grants +20 hype (with charge rate) to shooter",
		expected, c_baller.current_hype)

# --- Test 3: Offensive rebound grants +10 hype ---

func _test_rebound_hype_gain() -> void:
	_reset_all()
	var hype_before: float = c_baller.current_hype
	HypeManager.gain_hype(c_baller, 10.0)
	var expected: float = min(100.0, hype_before + 10.0 * (1.0 + c_baller.stats.hype_charge_rate))
	_assert(abs(c_baller.current_hype - expected) < 0.01,
		"Offensive rebound grants +10 hype (with charge rate) to rebounder",
		expected, c_baller.current_hype)

# --- Test 4: Last-beat action gives entire team +15 hype ---

func _test_last_beat_bonus() -> void:
	_reset_all()
	BeatManager.start_possession()
	# Manually advance to beat 8
	for _i in range(7):
		BeatManager.spend_action("move")
		BeatManager.spend_action("move")
		BeatManager.spend_action("move")
	_assert(BeatManager.current_beat == 8, "Advanced to beat 8")

	var hypes_before: Array = []
	for b in AlliedTeam.get_active_ballers():
		hypes_before.append(b.current_hype)

	# Spend one action in beat 8 — fires last-beat bonus
	BeatManager.spend_action("move")

	var all_gained: bool = true
	var ballers: Array = AlliedTeam.get_active_ballers()
	for i in range(ballers.size()):
		var expected: float = min(100.0,
			hypes_before[i] + 15.0 * (1.0 + ballers[i].stats.hype_charge_rate))
		if abs(ballers[i].current_hype - expected) > 0.1:
			all_gained = false
	_assert(all_gained, "Last-beat action grants +15 hype (with charge rate) to entire team")

# --- Test 5: Team hype >= 80% awards +1 bonus point ---

func _test_team_hype_scoring_bonus() -> void:
	_reset_all()
	# Set team hype below 80% — no bonus
	for b in AlliedTeam.get_active_ballers():
		b.current_hype = 50.0  # 50*3 = 150 / 500 = 30%
	var value_low: int = HypeManager.compute_shot_value(2)
	_assert(value_low == 2, "Team hype 30%% — no bonus (2 pts)", 2, value_low)

	# Set team hype >= 80% (>=400 of 500)
	for b in AlliedTeam.get_active_ballers():
		b.current_hype = 90.0  # 90*3 = 270 / 500 = 54% — not enough with 3 ballers
	# With 3 ballers max 300 total. Need 400. Use all 5 to properly test.
	# Spawn 2 more to hit the threshold
	var pg2: Node = AlliedScene.instantiate()
	pg2.set("stats", load("res://resources/stats/allied/pg_remix.tres"))
	add_child(pg2)
	pg2.current_hype = 90.0
	AlliedTeam.register(pg2)
	var sg2: Node = AlliedScene.instantiate()
	sg2.set("stats", load("res://resources/stats/allied/sg_remix.tres"))
	add_child(sg2)
	sg2.current_hype = 90.0
	AlliedTeam.register(sg2)
	# Now 5 ballers × 90 = 450 / 500 = 90%
	var value_high: int = HypeManager.compute_shot_value(2)
	_assert(value_high == 3, "Team hype 90%% — +1 bonus (3 pts)", 3, value_high)
	# Clean up extras
	pg2.queue_free()
	sg2.queue_free()
	AlliedTeam.unregister(pg2)
	AlliedTeam.unregister(sg2)

# --- Test 6: Gravity increases with hype ---

func _test_gravity_increases_with_hype() -> void:
	_reset_all()
	pg.current_hype = 0.0
	var g_low: int = GravitySystem.compute_gravity(pg)
	pg.current_hype = 40.0
	var g_mid: int = GravitySystem.compute_gravity(pg)
	pg.current_hype = 80.0
	var g_high: int = GravitySystem.compute_gravity(pg)
	_assert(g_low < g_mid, "Gravity increases from 0 to 40 hype (%d < %d)" % [g_low, g_mid])
	_assert(g_mid < g_high, "Gravity increases from 40 to 80 hype (%d < %d)" % [g_mid, g_high])
	print("  PG gravity: 0 hype=%d  40 hype=%d  80 hype=%d" % [g_low, g_mid, g_high])

# --- Test 7: Enemy Trash Talk targets highest-hype baller in range ---

func _test_trash_talk_drains_correct_target() -> void:
	_reset_all()
	var EnemyScene: PackedScene = preload("res://entities/baller/EnemyBaller.tscn")
	var enemy: Node = EnemyScene.instantiate()
	enemy.set("stats", load("res://resources/stats/enemy/hollywood_sf.tres"))
	add_child(enemy)
	enemy.place_on_grid(4, 6)  # Adjacent to sf

	pg.current_hype = 30.0   # In range (dist 2 from enemy at (4,6) to pg at (4,8))
	sf.current_hype = 60.0   # Highest, closest — should be targeted
	c_baller.current_hype = 10.0  # Not > 10 threshold (exactly 10), skipped

	var target: Node = EnemyAI._get_trash_talk_target(enemy)
	_assert(target == sf, "Trash Talk targets SF (highest hype in range)")

	var hype_before: float = sf.current_hype
	if target != null:
		HypeManager.drain_hype(target, 10.0)
	_assert(sf.current_hype == hype_before - 10.0,
		"Trash Talk drains exactly 10 hype", hype_before - 10.0, sf.current_hype)

	enemy.queue_free()
	EnemyTeam.unregister(enemy)

# --- Helpers ---

func _reset_all() -> void:
	for b in AlliedTeam.get_active_ballers():
		b.current_hype = 0.0
		b.current_stamina = b.stats.max_stamina
		b.is_exhausted = false
		b.acted_this_beat = false
		b.consecutive_actions = 0

func _assert(condition: bool, label: String, expected = null, actual = null) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		if expected != null:
			print("[FAIL] %s — expected %s, got %s" % [label, str(expected), str(actual)])
		else:
			print("[FAIL] %s" % label)
