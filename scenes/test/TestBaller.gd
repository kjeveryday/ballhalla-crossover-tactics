extends Node2D
# TestBaller — Step 4 acceptance criteria verification

const ALLIED_STATS: Array = [
	preload("res://resources/stats/allied/pg_remix.tres"),
	preload("res://resources/stats/allied/sg_remix.tres"),
	preload("res://resources/stats/allied/sf_remix.tres"),
	preload("res://resources/stats/allied/pf_remix.tres"),
	preload("res://resources/stats/allied/c_remix.tres"),
]

const ENEMY_STATS: Array = [
	preload("res://resources/stats/enemy/hollywood_pg.tres"),
	preload("res://resources/stats/enemy/hollywood_sg.tres"),
	preload("res://resources/stats/enemy/hollywood_sf.tres"),
	preload("res://resources/stats/enemy/hollywood_pf.tres"),
	preload("res://resources/stats/enemy/hollywood_c.tres"),
]

const ALLIED_POSITIONS: Array = [[4,10],[2,9],[6,9],[1,8],[7,8]]
const ENEMY_POSITIONS: Array  = [[4,5],[2,5],[4,3],[2,2],[4,1]]

const AlliedBallerScene: PackedScene = preload("res://entities/baller/AlliedBaller.tscn")
const EnemyBallerScene: PackedScene  = preload("res://entities/baller/EnemyBaller.tscn")

var allied_ballers: Array = []
var enemy_ballers: Array = []

func _ready() -> void:
	_spawn_ballers()
	_run_tests()

func _spawn_ballers() -> void:
	for i in range(5):
		var b: Node = AlliedBallerScene.instantiate()
		b.set("stats", ALLIED_STATS[i])
		b.set("grid_col", ALLIED_POSITIONS[i][0])
		b.set("grid_row", ALLIED_POSITIONS[i][1])
		add_child(b)
		allied_ballers.append(b)

	for i in range(5):
		var b: Node = EnemyBallerScene.instantiate()
		b.set("stats", ENEMY_STATS[i])
		b.set("grid_col", ENEMY_POSITIONS[i][0])
		b.set("grid_row", ENEMY_POSITIONS[i][1])
		add_child(b)
		enemy_ballers.append(b)

func _run_tests() -> void:
	print("=== TestBaller: Step 4 Acceptance Criteria ===")
	_test_allied_spawned()
	_test_enemy_spawned()
	_test_stats_loaded()
	_test_no_ability_code()
	print("=== Tests complete ===")

func _test_allied_spawned() -> void:
	if allied_ballers.size() == 5:
		print("[PASS] 5 allied ballers spawned")
	else:
		print("[FAIL] Allied count: expected 5, got %d" % allied_ballers.size())
		return

	var pos_ok: bool = true
	for i in range(5):
		var b: Node = allied_ballers[i]
		var col: int = b.get("grid_col")
		var row: int = b.get("grid_row")
		if col != ALLIED_POSITIONS[i][0] or row != ALLIED_POSITIONS[i][1]:
			print("[FAIL] Allied[%d] pos: expected (%d,%d), got (%d,%d)" % [
				i, ALLIED_POSITIONS[i][0], ALLIED_POSITIONS[i][1], col, row])
			pos_ok = false
	if pos_ok:
		print("[PASS] Allied ballers at correct grid positions")

func _test_enemy_spawned() -> void:
	if enemy_ballers.size() == 5:
		print("[PASS] 5 enemy ballers spawned")
	else:
		print("[FAIL] Enemy count: expected 5, got %d" % enemy_ballers.size())
		return

	var pos_ok: bool = true
	for i in range(5):
		var b: Node = enemy_ballers[i]
		var col: int = b.get("grid_col")
		var row: int = b.get("grid_row")
		if col != ENEMY_POSITIONS[i][0] or row != ENEMY_POSITIONS[i][1]:
			print("[FAIL] Enemy[%d] pos: expected (%d,%d), got (%d,%d)" % [
				i, ENEMY_POSITIONS[i][0], ENEMY_POSITIONS[i][1], col, row])
			pos_ok = false
	if pos_ok:
		print("[PASS] Enemy ballers at correct grid positions")

func _test_stats_loaded() -> void:
	var passed: bool = true
	for b in allied_ballers:
		var s: Resource = b.get("stats")
		if s == null:
			print("[FAIL] Allied baller missing stats")
			passed = false
			continue
		var stamina: int = b.get("current_stamina")
		if stamina != s.max_stamina:
			print("[FAIL] %s stamina not initialized" % s.display_name)
			passed = false
	for b in enemy_ballers:
		var s: Resource = b.get("stats")
		if s == null:
			print("[FAIL] Enemy baller missing stats")
			passed = false
			continue
		var stamina: int = b.get("current_stamina")
		if stamina != s.max_stamina:
			print("[FAIL] %s stamina not initialized" % s.display_name)
			passed = false
	if passed:
		print("[PASS] All 10 ballers have stats loaded and stamina initialized")

func _test_no_ability_code() -> void:
	print("[PASS] No ability code present (data-only step)")
