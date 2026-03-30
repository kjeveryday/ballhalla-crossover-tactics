extends Node2D
# TestStamina — Step 8 acceptance criteria
#
#   1. Three consecutive actions by one baller show visible stamina escalation
#   2. Switching to a different baller mid-beat resets the penalty for the first baller
#   3. Idle ballers show +8 stamina in debug log at beat end
#   4. Exhausted baller cannot act and receives no idle recovery

var AlliedBallerScene: PackedScene = preload("res://entities/baller/AlliedBaller.tscn")

var pg: Node = null
var sf: Node = null

func _ready() -> void:
	_spawn_ballers()
	print("=== TestStamina: Step 8 Acceptance Criteria ===")
	_run_tests()
	print("=== Done ===")

func _spawn_ballers() -> void:
	AlliedTeam.clear()
	pg = AlliedBallerScene.instantiate()
	pg.set("stats", load("res://resources/stats/allied/pg_remix.tres"))
	add_child(pg)
	pg.place_on_grid(4, 8)
	AlliedTeam.register(pg)

	sf = AlliedBallerScene.instantiate()
	sf.set("stats", load("res://resources/stats/allied/sf_remix.tres"))
	add_child(sf)
	sf.place_on_grid(4, 6)
	AlliedTeam.register(sf)

func _run_tests() -> void:
	_test_stamina_escalation()
	_test_switching_resets_penalty()
	_test_idle_recovery()
	_test_exhaustion_blocks_action()

# --- Test 1: Three consecutive actions escalate stamina cost ---

func _test_stamina_escalation() -> void:
	BeatManager.start_possession()
	_reset_ballers()

	var s0: int = pg.current_stamina
	pg.has_ball = true
	AbilitySystem.initiate_move(pg, Vector2i(4, 7))
	var cost_1: int = s0 - pg.current_stamina
	_assert(cost_1 == 10, "Consecutive 0 → cost 10", 10, cost_1)

	var s1: int = pg.current_stamina
	pg.is_in_motion = false
	AbilitySystem.initiate_move(pg, Vector2i(4, 6))
	var cost_2: int = s1 - pg.current_stamina
	_assert(cost_2 == 15, "Consecutive 1 → cost 15", 15, cost_2)

	var s2: int = pg.current_stamina
	pg.is_in_motion = false
	AbilitySystem.initiate_move(pg, Vector2i(4, 5))  # also ends beat (3rd action)
	var cost_3: int = s2 - pg.current_stamina
	_assert(cost_3 == 25, "Consecutive 2 → cost 25", 25, cost_3)
	_assert(pg.consecutive_actions == 0, "consecutive_actions reset to 0 at beat start after auto end-beat")

# --- Test 2: Switching ballers mid-beat resets ball-hog penalty ---

func _test_switching_resets_penalty() -> void:
	BeatManager.start_possession()
	_reset_ballers()

	# PG acts once → consecutive = 1
	pg.has_ball = true
	AbilitySystem.initiate_move(pg, Vector2i(4, 7))
	_assert(pg.consecutive_actions == 1, "PG consecutive = 1 after first action")

	# SF acts → PG's counter should reset to 0
	pg.is_in_motion = false
	AbilitySystem.initiate_move(sf, Vector2i(4, 5))
	_assert(pg.consecutive_actions == 0, "PG consecutive reset to 0 after SF acts")
	_assert(sf.consecutive_actions == 1, "SF consecutive = 1 after acting")

	# PG acts again → back to base cost
	var s_before: int = pg.current_stamina
	pg.is_in_motion = false
	AbilitySystem.initiate_move(pg, Vector2i(4, 6))  # ends beat (3rd action)
	var cost: int = s_before - pg.current_stamina
	_assert(cost == 10, "PG cost resets to 10 after SF acted", 10, cost)

# --- Test 3: Idle baller receives +8 recovery at beat end ---

func _test_idle_recovery() -> void:
	BeatManager.start_possession()
	_reset_ballers()
	# Drain some stamina from SF so recovery is measurable
	sf.drain_stamina(20)
	var sf_stamina_before: int = sf.current_stamina

	# Only PG acts — SF idles
	pg.has_ball = true
	AbilitySystem.initiate_move(pg, Vector2i(4, 7))
	AbilitySystem.initiate_move(pg, Vector2i(4, 6))  # PG acts twice
	pg.is_in_motion = false
	# End beat early — SF still idle
	BeatManager.end_beat_early()
	var sf_gained: int = sf.current_stamina - sf_stamina_before
	_assert(sf_gained == 8, "Idle SF recovers +8 stamina at beat end", 8, sf_gained)
	_assert(pg.acted_this_beat == false, "acted_this_beat cleared after beat end")

# --- Test 4: Exhausted baller cannot act and gets no idle recovery ---

func _test_exhaustion_blocks_action() -> void:
	BeatManager.start_possession()
	_reset_ballers()

	# Exhaust PG manually
	pg.current_stamina = 0
	pg.is_exhausted = true
	var stamina_snapshot: int = pg.current_stamina

	# Try to move — should be blocked
	AbilitySystem.initiate_move(pg, Vector2i(4, 7))
	_assert(not pg.is_in_motion, "Exhausted PG cannot initiate move")
	_assert(BeatManager.actions_remaining == 3, "No action spent when exhausted baller tries to act")

	# End beat — exhausted baller should NOT get idle recovery
	BeatManager.end_beat_early()
	_assert(pg.current_stamina == stamina_snapshot,
		"Exhausted PG receives no idle recovery", stamina_snapshot, pg.current_stamina)

# --- Helpers ---

func _reset_ballers() -> void:
	pg.place_on_grid(4, 8)
	pg.has_ball = false
	pg.is_in_motion = false
	pg.move_destination = Vector2i(-1, -1)
	pg.acted_this_beat = false
	pg.consecutive_actions = 0
	pg.is_exhausted = false
	pg.current_stamina = pg.stats.max_stamina

	sf.place_on_grid(4, 6)
	sf.has_ball = false
	sf.is_in_motion = false
	sf.move_destination = Vector2i(-1, -1)
	sf.acted_this_beat = false
	sf.consecutive_actions = 0
	sf.is_exhausted = false
	sf.current_stamina = sf.stats.max_stamina

func _assert(condition: bool, label: String, expected = null, actual = null) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		if expected != null:
			print("[FAIL] %s — expected %s, got %s" % [label, str(expected), str(actual)])
		else:
			print("[FAIL] %s" % label)
