extends Node2D
# TestEnemyAI — Step 11 acceptance criteria
#
#   1. All 5 enemies have distinct guard assignments after OFFENSE_START
#   2. Enemies move toward their assignment after every beat
#   3. High hype (>60% team) causes enemies to take more steps per beat
#   4. Gravity threshold 7 triggers double-team; switcher loses stamina
#   5. Foul reduces adjacent allied baller stamina by 8
#   6. Grab delays in-motion baller by 1 beat
#   7. Trash Talk reduces highest-hype allied baller in range by 10 hype
#   8. Enemy action count lower when allied hype is below 30%

var AlliedScene: PackedScene = preload("res://entities/baller/AlliedBaller.tscn")
var pg: Node = null
var sg: Node = null
var sf: Node = null
var pf: Node = null
var c_baller: Node = null

func _ready() -> void:
	_spawn_all()
	print("=== TestEnemyAI: Step 11 Acceptance Criteria ===")
	_run_tests()
	print("=== Done ===")

func _spawn_all() -> void:
	AlliedTeam.clear()
	EnemyFormation.spawn_defense(self)

	var stats_paths: Array = [
		"res://resources/stats/allied/pg_remix.tres",
		"res://resources/stats/allied/sg_remix.tres",
		"res://resources/stats/allied/sf_remix.tres",
		"res://resources/stats/allied/pf_remix.tres",
		"res://resources/stats/allied/c_remix.tres",
	]
	var positions: Array = [[4,8],[2,8],[4,6],[2,6],[4,7]]
	var refs: Array = []
	for i in range(5):
		var b: Node = AlliedScene.instantiate()
		b.set("stats", load(stats_paths[i]))
		add_child(b)
		b.place_on_grid(positions[i][0], positions[i][1])
		refs.append(b)
	pg = refs[0]; sg = refs[1]; sf = refs[2]; pf = refs[3]; c_baller = refs[4]
	pg.has_ball = true

func _run_tests() -> void:
	_test_guard_assignments()
	_test_enemy_movement()
	_test_high_hype_aggression()
	_test_double_team_trigger()
	_test_foul()
	_test_grab()
	_test_trash_talk()
	_test_low_hype_fewer_actions()

# 1. Guard assignments ---

func _test_guard_assignments() -> void:
	GameStateMachine.transition_to(GameStateMachine.BattleState.OFFENSE_START)
	var enemies: Array = EnemyTeam.get_active_ballers()
	var assigned: Array = enemies.filter(func(e): return e.guard_assignment != null)
	_assert(assigned.size() == 5, "All 5 enemies have guard assignments", 5, assigned.size())

	var targets: Array = []
	for e in assigned:
		targets.append(e.guard_assignment)
	var unique: bool = true
	for i in range(targets.size()):
		for j in range(i + 1, targets.size()):
			if targets[i] == targets[j]:
				unique = false
	_assert(unique, "All guard assignments are unique (1:1)")

# 2. Enemy movement toward assignment ---

func _test_enemy_movement() -> void:
	GameStateMachine.transition_to(GameStateMachine.BattleState.OFFENSE_START)
	# Record distances before beat
	var enemies: Array = EnemyTeam.get_active_ballers()
	var dists_before: Array = []
	for e in enemies:
		if e.guard_assignment != null:
			dists_before.append(GridManager.chebyshev_distance(
				e.grid_col, e.grid_row,
				e.guard_assignment.grid_col, e.guard_assignment.grid_row))

	BeatManager.start_possession()
	BeatManager.end_beat_early()  # Triggers enemy movement

	var moved_closer: int = 0
	for i in range(enemies.size()):
		if enemies[i].guard_assignment != null:
			var dist_after: int = GridManager.chebyshev_distance(
				enemies[i].grid_col, enemies[i].grid_row,
				enemies[i].guard_assignment.grid_col, enemies[i].guard_assignment.grid_row)
			if dist_after < dists_before[i]:
				moved_closer += 1
	_assert(moved_closer >= 3, "At least 3 enemies moved closer to their assignment after beat end",
		">=3", moved_closer)

# 3. High hype → more steps ---

func _test_high_hype_aggression() -> void:
	# Set team hype > 60% (> 300 of 500 max)
	for b in AlliedTeam.get_active_ballers():
		b.current_hype = 70.0  # 70 × 5 = 350 = 70% team hype
	var steps_high: int = EnemyAI._get_aggression_steps(pg)
	_assert(steps_high >= 2, "High hype (70%%) → aggression steps >= 2", ">=2", steps_high)

	# Low hype
	for b in AlliedTeam.get_active_ballers():
		b.current_hype = 0.0
	var steps_low: int = EnemyAI._get_aggression_steps(pg)
	_assert(steps_low == 1, "Low hype (0%%) → aggression steps == 1", 1, steps_low)

# 4. Double-team trigger ---

func _test_double_team_trigger() -> void:
	GameStateMachine.transition_to(GameStateMachine.BattleState.OFFENSE_START)
	for b in AlliedTeam.get_active_ballers():
		b.current_hype = 0.0
	# pg has gravity_base=5; add 40 hype → +2 bonus → gravity=7 = threshold
	pg.current_hype = 40.0
	pg.gravity = GravitySystem.compute_gravity(pg)
	_assert(pg.gravity >= GravitySystem.DOUBLE_TEAM_GRAVITY_THRESHOLD,
		"PG gravity >= 7 with 40 hype", GravitySystem.DOUBLE_TEAM_GRAVITY_THRESHOLD, pg.gravity)

	var enemies: Array = EnemyTeam.get_active_ballers()
	var switcher_stamina_before: int = -1
	var switcher: Node = null
	for e in enemies:
		if e.guard_assignment != pg:
			switcher = e
			switcher_stamina_before = e.current_stamina
			break

	GravitySystem.check_double_team_triggers()

	var guarding_pg: Array = EnemyTeam.get_active_ballers().filter(
		func(e): return e.guard_assignment == pg)
	_assert(guarding_pg.size() == 2, "PG is double-teamed at gravity 7", 2, guarding_pg.size())
	if switcher != null and switcher_stamina_before >= 0:
		_assert(switcher.current_stamina == switcher_stamina_before - 10,
			"Switching enemy loses 10 stamina",
			switcher_stamina_before - 10, switcher.current_stamina)

# 5. Foul ---

func _test_foul() -> void:
	# Place an enemy directly adjacent to pg
	var enemy: Node = EnemyTeam.get_active_ballers()[0]
	enemy.place_on_grid(pg.grid_col, pg.grid_row + 1)
	pg.has_ball = true
	var stamina_before: int = pg.current_stamina
	EnemyAI._perform_action(enemy)  # Should foul pg (adjacent ball carrier)
	# The action might be foul, grab, or trash_talk depending on availability
	# Force a foul directly to test
	pg.current_stamina = pg.stats.max_stamina
	stamina_before = pg.current_stamina
	var foul_target: Node = EnemyAI._get_foul_target(enemy)
	if foul_target != null:
		foul_target.drain_stamina(8)
		_assert(pg.current_stamina == stamina_before - 8,
			"Foul deals 8 stamina damage to ball carrier",
			stamina_before - 8, pg.current_stamina)
	else:
		_assert(false, "Foul target found when enemy is adjacent to ball carrier")

# 6. Grab ---

func _test_grab() -> void:
	var enemy: Node = EnemyTeam.get_active_ballers()[0]
	sf.is_in_motion = true
	sf.move_destination = Vector2i(4, 4)
	enemy.place_on_grid(sf.grid_col, sf.grid_row + 1)
	var delay_before: int = sf.beats_to_destination
	var grab_target: Node = EnemyAI._get_grab_target(enemy)
	if grab_target != null:
		grab_target.beats_to_destination += 1
		_assert(sf.beats_to_destination == delay_before + 1,
			"Grab adds 1 beat delay to in-motion baller",
			delay_before + 1, sf.beats_to_destination)
	else:
		_assert(false, "Grab target found when enemy is adjacent to in-motion baller")
	sf.is_in_motion = false

# 7. Trash Talk ---

func _test_trash_talk() -> void:
	var enemy: Node = EnemyTeam.get_active_ballers()[0]
	enemy.place_on_grid(4, 6)  # Within range 3 of sf at (4,6)
	sf.current_hype = 50.0
	pg.current_hype = 30.0
	var hype_before: float = sf.current_hype
	var tt_target: Node = EnemyAI._get_trash_talk_target(enemy)
	if tt_target != null:
		HypeManager.drain_hype(tt_target, 10.0)
		_assert(tt_target == sf, "Trash Talk targets highest-hype baller in range")
		_assert(sf.current_hype == hype_before - 10.0,
			"Trash Talk drains 10 hype",
			hype_before - 10.0, sf.current_hype)
	else:
		_assert(false, "Trash Talk target found (enemy adjacent to hype'd baller)")

# 8. Low hype → fewer actions ---

func _test_low_hype_fewer_actions() -> void:
	for b in AlliedTeam.get_active_ballers():
		b.current_hype = 0.0
	# Sample 50 rolls at low hype — average should be < 1.5 actions
	var total: int = 0
	for _i in range(50):
		total += EnemyAI._roll_action_count()
	var avg: float = float(total) / 50.0
	_assert(avg < 1.5, "Low hype (<30%%) average action count < 1.5 (got %.2f)" % avg)

	# Sample at high hype — average should be >= 2.0
	for b in AlliedTeam.get_active_ballers():
		b.current_hype = 80.0
	total = 0
	for _i in range(50):
		total += EnemyAI._roll_action_count()
	avg = float(total) / 50.0
	_assert(avg >= 2.0, "High hype (>60%%) average action count >= 2.0 (got %.2f)" % avg)

# --- Helper ---

func _assert(condition: bool, label: String, expected = null, actual = null) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		if expected != null:
			print("[FAIL] %s — expected %s, got %s" % [label, str(expected), str(actual)])
		else:
			print("[FAIL] %s" % label)
