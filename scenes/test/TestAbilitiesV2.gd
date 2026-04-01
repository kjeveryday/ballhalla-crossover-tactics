extends Node2D
# TestAbilitiesV2 — Step 13 acceptance criteria
#
#   1. Screen nullifies the enemy's guard_assignment for 1 beat
#   2. Screen grants +2% shot bonus to nearby allies
#   3. screen_recovery_timer decrements; enemy re-assigns after 1 beat
#   4. Talk: Trash Talk drains -10 stamina from enemies within range 5
#   5. Talk: Leadership grants +10 hype to target ally
#   6. Talk: ISO drains -5 stamina from enemies within range 3
#   7. Play call must be first action in beat (rejects if not)
#   8. Play call + sequence completion triggers shot bonus
#   9. Pick-and-Roll (screen→cut→pass) triggers +15% shot bonus
#  10. Drive-and-Kick (move→pass) triggers +10% bonus + free stamina shot

var AlliedScene: PackedScene = preload("res://entities/baller/AlliedBaller.tscn")
var EnemyScene: PackedScene = preload("res://entities/baller/EnemyBaller.tscn")

var pg: Node = null
var sf: Node = null
var sg: Node = null
var enemy_pg: Node = null
var enemy_sf: Node = null

func _ready() -> void:
	_spawn_ballers()
	print("=== TestAbilitiesV2: Step 13 Acceptance Criteria ===")
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
	sf.place_on_grid(3, 7)
	AlliedTeam.register(sf)

	sg = AlliedScene.instantiate()
	sg.set("stats", load("res://resources/stats/allied/sg_remix.tres"))
	add_child(sg)
	sg.place_on_grid(5, 7)
	AlliedTeam.register(sg)

	enemy_pg = EnemyScene.instantiate()
	enemy_pg.set("stats", load("res://resources/stats/enemy/hollywood_pg.tres"))
	add_child(enemy_pg)
	enemy_pg.place_on_grid(4, 7)
	EnemyTeam.register(enemy_pg)

	enemy_sf = EnemyScene.instantiate()
	enemy_sf.set("stats", load("res://resources/stats/enemy/hollywood_sf.tres"))
	add_child(enemy_sf)
	enemy_sf.place_on_grid(3, 6)
	EnemyTeam.register(enemy_sf)

	# Assign guards
	enemy_pg.guard_assignment = pg
	enemy_sf.guard_assignment = sf

func _run_tests() -> void:
	_test_screen_nullifies_guard()
	_test_screen_shot_bonus_nearby()
	_test_screen_recovery_timer()
	_test_talk_trash()
	_test_talk_leadership()
	_test_talk_iso()
	_test_play_call_must_be_first()
	_test_play_call_registers()
	_test_pick_and_roll_sequence()
	_test_drive_and_kick_sequence()

# --- Test 1: Screen nullifies the enemy's guard_assignment ---

func _test_screen_nullifies_guard() -> void:
	_reset_all()
	_assert(enemy_pg.guard_assignment == pg, "Setup: enemy_pg guards pg")
	AbilitySystem.perform_screen(pg)
	_assert(enemy_pg.guard_assignment == null,
		"Screen: enemy_pg guard_assignment nullified")
	_assert(pg.screen_recovery_timer == 1,
		"Screen: screener recovery timer set to 1", 1, pg.screen_recovery_timer)

# --- Test 2: Screen grants +2% shot bonus to nearby allies ---

func _test_screen_shot_bonus_nearby() -> void:
	_reset_all()
	PlayManager.pending_shot_bonus = 0.0
	# sf is at (3,7), sg at (5,7) — both within chebyshev dist 2 of pg at (4,8)
	AbilitySystem.perform_screen(pg)
	_assert(PlayManager.pending_shot_bonus > 0.0,
		"Screen: pending_shot_bonus > 0 for nearby allies")
	print("  pending_shot_bonus after screen: %.2f" % PlayManager.pending_shot_bonus)

# --- Test 3: Screen recovery timer decrements and enemy re-assigns ---

func _test_screen_recovery_timer() -> void:
	_reset_all()
	enemy_pg.guard_assignment = pg
	pg.screen_recovery_timer = 0
	AbilitySystem.perform_screen(pg)
	_assert(pg.screen_recovery_timer == 1,
		"Screen: timer starts at 1", 1, pg.screen_recovery_timer)
	_assert(enemy_pg.guard_assignment == null,
		"Screen: enemy guard cleared immediately")
	# Simulate beat end — EnemyAI.update_enemy_movement() decrements timer
	EnemyAI.update_enemy_movement()
	_assert(pg.screen_recovery_timer == 0,
		"After 1 beat: timer reaches 0", 0, pg.screen_recovery_timer)
	_assert(enemy_pg.guard_assignment == pg,
		"After timer expires: enemy re-assigns to pg")

# --- Test 4: Talk Trash drains enemy stamina within range 5 ---

func _test_talk_trash() -> void:
	_reset_all()
	# enemy_pg at (4,7) — dist 1 from pg at (4,8) — within range 5
	# enemy_sf at (3,6) — dist 2 from pg — within range 5
	var e_pg_stam_before: int = enemy_pg.current_stamina
	var e_sf_stam_before: int = enemy_sf.current_stamina
	AbilitySystem.talk_trash(pg)
	_assert(enemy_pg.current_stamina == e_pg_stam_before - 10,
		"Trash Talk: enemy_pg loses 10 stamina", e_pg_stam_before - 10, enemy_pg.current_stamina)
	_assert(enemy_sf.current_stamina == e_sf_stam_before - 10,
		"Trash Talk: enemy_sf loses 10 stamina", e_sf_stam_before - 10, enemy_sf.current_stamina)

# --- Test 5: Leadership grants +10 hype to target ally ---

func _test_talk_leadership() -> void:
	_reset_all()
	sf.current_hype = 20.0
	var hype_before: float = sf.current_hype
	AbilitySystem.talk_leadership(pg, sf)
	var expected: float = min(100.0, hype_before + 10.0 * (1.0 + sf.stats.hype_charge_rate))
	_assert(abs(sf.current_hype - expected) < 0.01,
		"Leadership: sf gains +10 hype (with charge rate)", expected, sf.current_hype)

# --- Test 6: ISO talk drains -5 stamina from enemies within range 3 ---

func _test_talk_iso() -> void:
	_reset_all()
	# pg at (4,8), enemy_pg at (4,7) dist=1, enemy_sf at (3,6) dist=2 — both in range 3
	var e_pg_stam_before: int = enemy_pg.current_stamina
	var e_sf_stam_before: int = enemy_sf.current_stamina
	AbilitySystem.talk_iso(pg)
	_assert(enemy_pg.current_stamina == e_pg_stam_before - 5,
		"ISO Talk: enemy_pg loses 5 stamina", e_pg_stam_before - 5, enemy_pg.current_stamina)
	_assert(enemy_sf.current_stamina == e_sf_stam_before - 5,
		"ISO Talk: enemy_sf loses 5 stamina", e_sf_stam_before - 5, enemy_sf.current_stamina)
	_assert(PlayManager.iso_baller == pg,
		"ISO Talk: iso_baller set to pg")

# --- Test 7: Play call rejected unless first action of beat ---

func _test_play_call_must_be_first() -> void:
	_reset_all()
	BeatManager.start_possession()
	# Spend one action first
	BeatManager.actions_remaining -= 1
	var active_before = PlayManager.active_play
	AbilitySystem.call_play("pick_and_roll")
	_assert(PlayManager.active_play == active_before,
		"Play call rejected when not first action in beat")
	# Reset remaining
	BeatManager.actions_remaining = BeatManager.ACTIONS_PER_BEAT

# --- Test 8: Play call as first action registers the play ---

func _test_play_call_registers() -> void:
	_reset_all()
	BeatManager.start_possession()
	PlayManager.active_play = null
	AbilitySystem.call_play("give_and_go")
	_assert(PlayManager.active_play != null,
		"Play call: active_play is set after call_play")
	if PlayManager.active_play != null:
		_assert(PlayManager.active_play.play_name == "Give and Go",
			"Play call: correct play registered", "Give and Go", PlayManager.active_play.play_name)

# --- Test 9: Pick-and-Roll sequence triggers +15% shot bonus ---

func _test_pick_and_roll_sequence() -> void:
	_reset_all()
	PlayManager.active_play = null
	PlayManager.sequence_progress.clear()
	PlayManager.pending_shot_bonus = 0.0
	# Manually call the play and feed sequence
	PlayManager.call_play("pick_and_roll")
	_assert(PlayManager.active_play != null, "Pick-and-Roll: play set")
	PlayManager.on_action_resolved("screen")
	PlayManager.on_action_resolved("cut")
	PlayManager.on_action_resolved("pass")
	_assert(PlayManager.active_play == null,
		"Pick-and-Roll: play cleared after sequence complete")
	_assert(abs(PlayManager.pending_shot_bonus - 0.15) < 0.001,
		"Pick-and-Roll: +15%% shot bonus pending", 0.15, PlayManager.pending_shot_bonus)

# --- Test 10: Drive-and-Kick triggers +10% bonus + free stamina ---

func _test_drive_and_kick_sequence() -> void:
	_reset_all()
	PlayManager.active_play = null
	PlayManager.sequence_progress.clear()
	PlayManager.pending_shot_bonus = 0.0
	PlayManager.pending_shot_no_stamina = false
	PlayManager.call_play("drive_and_kick")
	PlayManager.on_action_resolved("move")
	PlayManager.on_action_resolved("pass")
	_assert(PlayManager.active_play == null,
		"Drive-and-Kick: play cleared after sequence complete")
	_assert(abs(PlayManager.pending_shot_bonus - 0.10) < 0.001,
		"Drive-and-Kick: +10%% shot bonus pending", 0.10, PlayManager.pending_shot_bonus)
	_assert(PlayManager.pending_shot_no_stamina == true,
		"Drive-and-Kick: free stamina shot pending")

# --- Helpers ---

func _reset_all() -> void:
	PlayManager.active_play = null
	PlayManager.sequence_progress.clear()
	PlayManager.pending_shot_bonus = 0.0
	PlayManager.pending_shot_no_stamina = false
	PlayManager.iso_baller = null
	BeatManager.actions_remaining = BeatManager.ACTIONS_PER_BEAT
	enemy_pg.guard_assignment = pg
	enemy_sf.guard_assignment = sf
	pg.screen_recovery_timer = 0
	for b in AlliedTeam.get_active_ballers():
		b.current_stamina = b.stats.max_stamina
		b.is_exhausted = false
		b.acted_this_beat = false
		b.consecutive_actions = 0
		b.current_hype = 0.0
		b.screen_recovery_timer = 0
	for e in EnemyTeam.get_active_ballers():
		e.current_stamina = e.stats.max_stamina
		e.is_exhausted = false

func _assert(condition: bool, label: String, expected = null, actual = null) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		if expected != null:
			print("[FAIL] %s — expected %s, got %s" % [label, str(expected), str(actual)])
		else:
			print("[FAIL] %s" % label)
