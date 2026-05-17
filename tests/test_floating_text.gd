extends GutTest

# ---------------------------------------------------------------------------
# Helpers / stubs
# ---------------------------------------------------------------------------

var _court: Node2D
var _spawner: Node
var _stamina_system: Node
var _shot_system: Node
var _hype_manager: Node

var _fake_baller: Node2D
var _fake_baller2: Node2D


func _make_baller(pos: Vector2 = Vector2(100.0, 200.0)) -> Node2D:
	var b := Node2D.new()
	b.position = pos
	add_child(b)
	return b


func _label_in(node: Node) -> Label:
	for child in node.get_children():
		if child is Label:
			return child
	return null


func _first_floating_child(parent: Node) -> Node:
	for child in parent.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("FloatingText.gd"):
			return child
	return null


# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

func before_each() -> void:
	_court = Node2D.new()
	add_child_autofree(_court)

	_spawner = load("res://src/ui/FloatingTextSpawner.gd").new()
	# Inject the court reference; implementation must expose _court as an @export
	# or provide a set_court() method.  The test calls set_court() and falls back
	# to direct property assignment so either API works.
	if _spawner.has_method("set_court"):
		_spawner.set_court(_court)
	else:
		_spawner.set("_court", _court)
	add_child_autofree(_spawner)

	_stamina_system = load("res://src/systems/StaminaSystem.gd").new()
	add_child_autofree(_stamina_system)

	_shot_system = load("res://src/systems/ShotSystem.gd").new()
	add_child_autofree(_shot_system)

	_hype_manager = load("res://src/systems/HypeManager.gd").new()
	add_child_autofree(_hype_manager)

	_fake_baller = _make_baller(Vector2(100.0, 200.0))
	_fake_baller2 = _make_baller(Vector2(300.0, 400.0))


func after_each() -> void:
	_fake_baller.queue_free()
	_fake_baller2.queue_free()


# ===========================================================================
# 15A — StaminaSystem.stamina_changed Signal
# ===========================================================================

func test_stamina_system_emits_stamina_changed_after_drain() -> void:
	# Behavior 1: drain_stamina triggers stamina_changed with negative delta
	watch_signals(_stamina_system)
	_stamina_system.drain_stamina(_fake_baller, 10)
	assert_signal_emitted(_stamina_system, "stamina_changed",
		"StaminaSystem must emit stamina_changed after drain_stamina resolves")


func test_stamina_changed_carries_negative_delta_for_drain() -> void:
	# Behavior 3 (drain side): delta must be negative for a drain
	watch_signals(_stamina_system)
	_stamina_system.drain_stamina(_fake_baller, 10)
	var args: Array = get_signal_parameters(_stamina_system, "stamina_changed", 0)
	assert_lt(args[1], 0,
		"stamina_changed delta must be negative when draining stamina")


func test_stamina_system_emits_stamina_changed_after_idle_recovery() -> void:
	# Behavior 2: apply_idle_recovery triggers stamina_changed with positive delta
	watch_signals(_stamina_system)
	_stamina_system.apply_idle_recovery(_fake_baller)
	assert_signal_emitted(_stamina_system, "stamina_changed",
		"StaminaSystem must emit stamina_changed after apply_idle_recovery")


func test_stamina_changed_carries_positive_delta_for_heal() -> void:
	# Behavior 3 (heal side): delta must be positive for a heal
	watch_signals(_stamina_system)
	_stamina_system.apply_idle_recovery(_fake_baller)
	var args: Array = get_signal_parameters(_stamina_system, "stamina_changed", 0)
	assert_gt(args[1], 0,
		"stamina_changed delta must be positive when healing stamina")


func test_stamina_changed_carries_baller_in_payload() -> void:
	# Behavior 1/2: signal payload must include the baller node
	watch_signals(_stamina_system)
	_stamina_system.drain_stamina(_fake_baller, 5)
	var args: Array = get_signal_parameters(_stamina_system, "stamina_changed", 0)
	assert_eq(args[0], _fake_baller,
		"stamina_changed payload[0] must be the baller whose stamina changed")


# ===========================================================================
# 15B — FloatingText Node
# ===========================================================================

func test_spawn_adds_floating_text_as_child_of_parent() -> void:
	# Behavior 5: FloatingText.spawn must add itself to the given parent
	var FloatingText := load("res://src/ui/FloatingText.gd")
	FloatingText.spawn(_court, Vector2(50.0, 50.0), "TEST", Color.WHITE, 16)
	assert_gt(_court.get_child_count(), 0,
		"FloatingText.spawn must add a child node to the parent")


func test_spawn_positions_node_at_world_pos() -> void:
	# Behavior 5: spawned node must be positioned at world_pos
	var FloatingText := load("res://src/ui/FloatingText.gd")
	var target_pos := Vector2(123.0, 456.0)
	FloatingText.spawn(_court, target_pos, "POS", Color.WHITE, 16)
	var spawned: Node = _first_floating_child(_court)
	assert_not_null(spawned, "A FloatingText node must have been added to the court")
	assert_eq((spawned as Node2D).position, target_pos,
		"Spawned FloatingText must be positioned at the given world_pos")


func test_spawn_creates_label_with_correct_text() -> void:
	# Behavior 6: spawned node must contain a Label showing the given text
	var FloatingText := load("res://src/ui/FloatingText.gd")
	FloatingText.spawn(_court, Vector2.ZERO, "HELLO", Color.WHITE, 16)
	var spawned: Node = _first_floating_child(_court)
	assert_not_null(spawned, "A FloatingText node must have been added to the court")
	var label: Label = _label_in(spawned)
	assert_not_null(label, "Spawned FloatingText must contain a Label child")
	assert_eq(label.text, "HELLO",
		"Label text must match the text argument passed to spawn()")


func test_spawn_creates_label_with_correct_color() -> void:
	# Behavior 6: label must use the provided color
	var FloatingText := load("res://src/ui/FloatingText.gd")
	FloatingText.spawn(_court, Vector2.ZERO, "COLOR", Color.RED, 16)
	var spawned: Node = _first_floating_child(_court)
	var label: Label = _label_in(spawned)
	assert_not_null(label, "Spawned FloatingText must contain a Label child")
	assert_eq(label.modulate, Color.RED,
		"Label color must match the color argument passed to spawn()")


func test_spawn_creates_label_with_correct_font_size() -> void:
	# Behavior 6: label must use the provided font size
	var FloatingText := load("res://src/ui/FloatingText.gd")
	FloatingText.spawn(_court, Vector2.ZERO, "SIZE", Color.WHITE, 22)
	var spawned: Node = _first_floating_child(_court)
	var label: Label = _label_in(spawned)
	assert_not_null(label, "Spawned FloatingText must contain a Label child")
	assert_eq(label.get_theme_font_size("font_size"), 22,
		"Label font size must match the font_size argument passed to spawn()")


func test_spawn_begins_tween_that_moves_node_upward() -> void:
	# Behavior 7: a tween must begin that raises the node's Y by FLOATING_TEXT_RISE_PX
	# Observable: after a short time the node's Y is less (higher) than start
	var FloatingText := load("res://src/ui/FloatingText.gd")
	var start_pos := Vector2(0.0, 0.0)
	FloatingText.spawn(_court, start_pos, "UP", Color.WHITE, 16)
	var spawned: Node = _first_floating_child(_court)
	assert_not_null(spawned, "A FloatingText node must have been added to the court")
	# Advance physics one frame so the tween can tick
	await get_tree().process_frame
	assert_lt((spawned as Node2D).position.y, start_pos.y,
		"FloatingText tween must move the node upward (decreasing Y) from its spawn position")


func test_spawn_begins_tween_that_fades_label_alpha() -> void:
	# Behavior 8: the tween must fade the label's alpha from 1.0 toward 0.0
	var FloatingText := load("res://src/ui/FloatingText.gd")
	FloatingText.spawn(_court, Vector2.ZERO, "FADE", Color.WHITE, 16)
	var spawned: Node = _first_floating_child(_court)
	assert_not_null(spawned, "A FloatingText node must have been added to the court")
	await get_tree().process_frame
	var label: Label = _label_in(spawned)
	assert_lt(label.modulate.a, 1.0,
		"FloatingText tween must decrease the label alpha below 1.0 after spawning")


func test_floating_text_frees_itself_after_tween_completes() -> void:
	# Behavior 9: node must call queue_free() when the tween finishes
	var FloatingText := load("res://src/ui/FloatingText.gd")
	FloatingText.spawn(_court, Vector2.ZERO, "FREE", Color.WHITE, 16)
	var spawned: Node = _first_floating_child(_court)
	assert_not_null(spawned, "A FloatingText node must have been added to the court")
	# Wait longer than FLOATING_TEXT_DURATION_SEC (0.7 s) + a safety margin
	await get_tree().create_timer(1.0).timeout
	assert_false(is_instance_valid(spawned),
		"FloatingText must queue_free itself after its tween completes")


# ===========================================================================
# 15C — FloatingTextSpawner Typed Methods
# ===========================================================================

func test_spawn_score_produces_white_label_at_22px() -> void:
	# Behavior 11: spawn_score → "+N", size 22, Color.WHITE
	_spawner.spawn_score(Vector2(0.0, 0.0), 2)
	var spawned: Node = _first_floating_child(_court)
	assert_not_null(spawned, "spawn_score must produce a FloatingText node in the court")
	var label: Label = _label_in(spawned)
	assert_eq(label.text, "+2",
		"spawn_score label text must be '+' concatenated with the points value")
	assert_eq(label.get_theme_font_size("font_size"), 22,
		"spawn_score must use FLOATING_TEXT_SIZE_LARGE (22px)")
	assert_eq(label.modulate, Color.WHITE,
		"spawn_score label must be white")


func test_spawn_miss_produces_red_miss_label_at_16px() -> void:
	# Behavior 12: spawn_miss → "MISS", size 16, Color.RED
	_spawner.spawn_miss(Vector2(0.0, 0.0))
	var spawned: Node = _first_floating_child(_court)
	assert_not_null(spawned, "spawn_miss must produce a FloatingText node in the court")
	var label: Label = _label_in(spawned)
	assert_eq(label.text, "MISS",
		"spawn_miss label text must be 'MISS'")
	assert_eq(label.get_theme_font_size("font_size"), 16,
		"spawn_miss must use FLOATING_TEXT_SIZE_MEDIUM (16px)")
	assert_eq(label.modulate, Color.RED,
		"spawn_miss label must be red")


func test_spawn_stamina_negative_delta_produces_red_label() -> void:
	# Behavior 13 (drain): "-N STM", size 13, Color.RED
	_spawner.spawn_stamina(Vector2(0.0, 0.0), -10)
	var spawned: Node = _first_floating_child(_court)
	assert_not_null(spawned, "spawn_stamina must produce a FloatingText node in the court")
	var label: Label = _label_in(spawned)
	assert_eq(label.text, "-10 STM",
		"spawn_stamina label must be '-10 STM' for delta == -10")
	assert_eq(label.get_theme_font_size("font_size"), 13,
		"spawn_stamina must use FLOATING_TEXT_SIZE_SMALL (13px)")
	assert_eq(label.modulate, Color.RED,
		"spawn_stamina label must be red when delta is negative")


func test_spawn_stamina_positive_delta_produces_green_label() -> void:
	# Behavior 13 (heal): "+N STM", size 13, Color.GREEN
	_spawner.spawn_stamina(Vector2(0.0, 0.0), 8)
	var spawned: Node = _first_floating_child(_court)
	assert_not_null(spawned, "spawn_stamina must produce a FloatingText node in the court")
	var label: Label = _label_in(spawned)
	assert_eq(label.text, "8 STM",
		"spawn_stamina label must be '8 STM' for delta == 8 (str(8) yields '8')")
	assert_eq(label.get_theme_font_size("font_size"), 13,
		"spawn_stamina must use FLOATING_TEXT_SIZE_SMALL (13px)")
	assert_eq(label.modulate, Color.GREEN,
		"spawn_stamina label must be green when delta is positive")


func test_spawn_hype_produces_gold_label_at_13px() -> void:
	# Behavior 14: "+N HYPE", size 13, gold color
	_spawner.spawn_hype(Vector2(0.0, 0.0), 10)
	var spawned: Node = _first_floating_child(_court)
	assert_not_null(spawned, "spawn_hype must produce a FloatingText node in the court")
	var label: Label = _label_in(spawned)
	assert_eq(label.text, "10 HYPE",
		"spawn_hype label must be '10 HYPE' for delta == 10")
	assert_eq(label.get_theme_font_size("font_size"), 13,
		"spawn_hype must use FLOATING_TEXT_SIZE_SMALL (13px)")
	assert_eq(label.modulate, Color(1.0, 0.84, 0.0, 1.0),
		"spawn_hype label must be gold (Color(1.0, 0.84, 0.0, 1.0))")


func test_spawn_event_produces_white_verbatim_label_at_15px() -> void:
	# Behavior 15: verbatim text, size 15, Color.WHITE
	_spawner.spawn_event(Vector2(0.0, 0.0), "REBOUND")
	var spawned: Node = _first_floating_child(_court)
	assert_not_null(spawned, "spawn_event must produce a FloatingText node in the court")
	var label: Label = _label_in(spawned)
	assert_eq(label.text, "REBOUND",
		"spawn_event label must display the text verbatim")
	assert_eq(label.get_theme_font_size("font_size"), 15,
		"spawn_event must use FLOATING_TEXT_GENERIC_EVENT_SIZE (15px)")
	assert_eq(label.modulate, Color.WHITE,
		"spawn_event label must be white")


func test_all_typed_methods_pass_court_as_parent() -> void:
	# Behavior 16: all spawned nodes must be children of _court, not the spawner
	_spawner.spawn_score(Vector2.ZERO, 3)
	_spawner.spawn_miss(Vector2.ZERO)
	_spawner.spawn_stamina(Vector2.ZERO, -5)
	_spawner.spawn_hype(Vector2.ZERO, 5)
	_spawner.spawn_event(Vector2.ZERO, "TEST")
	var court_children: int = 0
	for child in _court.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("FloatingText.gd"):
			court_children += 1
	assert_eq(court_children, 5,
		"All five typed methods must spawn FloatingText nodes as children of the court node")


# ===========================================================================
# Signal Wiring — Behaviors 17–22
# ===========================================================================

func test_shot_made_signal_triggers_spawn_score_at_shooter_position() -> void:
	# Behavior 17
	_fake_baller.position = Vector2(77.0, 88.0)
	_shot_system.emit_signal("shot_made", _fake_baller, 3)
	await get_tree().process_frame
	var spawned: Node = _first_floating_child(_court)
	assert_not_null(spawned, "shot_made signal must trigger a FloatingText spawn in the court")
	assert_eq((spawned as Node2D).position, Vector2(77.0, 88.0),
		"Score text must spawn at the shooter's position")
	var label: Label = _label_in(spawned)
	assert_eq(label.text, "+3",
		"Score text from shot_made must display the point value")


func test_shot_missed_signal_triggers_spawn_miss_at_shooter_position() -> void:
	# Behavior 18
	_fake_baller.position = Vector2(55.0, 66.0)
	_shot_system.emit_signal("shot_missed", _fake_baller)
	await get_tree().process_frame
	var spawned: Node = _first_floating_child(_court)
	assert_not_null(spawned, "shot_missed signal must trigger a FloatingText spawn in the court")
	assert_eq((spawned as Node2D).position, Vector2(55.0, 66.0),
		"Miss text must spawn at the shooter's position")
	var label: Label = _label_in(spawned)
	assert_eq(label.text, "MISS",
		"Miss text from shot_missed must display 'MISS'")


func test_stamina_changed_signal_triggers_spawn_stamina() -> void:
	# Behavior 19
	_fake_baller.position = Vector2(33.0, 44.0)
	_stamina_system.emit_signal("stamina_changed", _fake_baller, -7)
	await get_tree().process_frame
	var spawned: Node = _first_floating_child(_court)
	assert_not_null(spawned, "stamina_changed signal must trigger a FloatingText spawn in the court")
	var label: Label = _label_in(spawned)
	assert_eq(label.text, "-7 STM",
		"Stamina text from stamina_changed must display the signed delta")


func test_hype_changed_signal_triggers_spawn_hype() -> void:
	# Behavior 20
	_fake_baller.position = Vector2(11.0, 22.0)
	_hype_manager.emit_signal("hype_changed", _fake_baller, 5.0)
	await get_tree().process_frame
	var spawned: Node = _first_floating_child(_court)
	assert_not_null(spawned, "hype_changed signal must trigger a FloatingText spawn in the court")
	var label: Label = _label_in(spawned)
	assert_true(label.text.contains("HYPE"),
		"Hype text from hype_changed must contain 'HYPE'")


func test_rebound_won_signal_triggers_spawn_event_rebound() -> void:
	# Behavior 21
	_fake_baller.position = Vector2(99.0, 111.0)
	_shot_system.emit_signal("rebound_won", _fake_baller, null)
	await get_tree().process_frame
	var spawned: Node = _first_floating_child(_court)
	assert_not_null(spawned, "rebound_won signal must trigger a FloatingText spawn in the court")
	var label: Label = _label_in(spawned)
	assert_eq(label.text, "REBOUND",
		"Rebound text from rebound_won must display 'REBOUND'")


func test_signal_connections_exist_before_first_frame() -> void:
	# Behavior 22: connections must exist immediately after spawner is added to tree
	# We verify via has_signal + is_connected on each signal source.
	assert_true(
		_stamina_system.is_connected("stamina_changed", Callable(_spawner, "_on_stamina_changed")),
		"FloatingTextSpawner must connect to StaminaSystem.stamina_changed during _ready()")
	assert_true(
		_shot_system.is_connected("shot_made", Callable(_spawner, "_on_shot_made")),
		"FloatingTextSpawner must connect to ShotSystem.shot_made during _ready()")
	assert_true(
		_shot_system.is_connected("shot_missed", Callable(_spawner, "_on_shot_missed")),
		"FloatingTextSpawner must connect to ShotSystem.shot_missed during _ready()")
	assert_true(
		_hype_manager.is_connected("hype_changed", Callable(_spawner, "_on_hype_changed")),
		"FloatingTextSpawner must connect to HypeManager.hype_changed during _ready()")
	assert_true(
		_shot_system.is_connected("rebound_won", Callable(_spawner, "_on_rebound_won")),
		"FloatingTextSpawner must connect to ShotSystem.rebound_won during _ready()")


# ===========================================================================
# Edge Cases
# ===========================================================================

func test_spawn_stamina_zero_delta_does_not_spawn_floating_text() -> void:
	# Edge case: delta == 0 must not spawn anything
	_spawner.spawn_stamina(Vector2.ZERO, 0)
	var spawned: Node = _first_floating_child(_court)
	assert_null(spawned,
		"spawn_stamina must not spawn a FloatingText when delta is zero")


func test_spawn_hype_zero_delta_does_not_spawn_floating_text() -> void:
	# Edge case: delta == 0 must not spawn anything
	_spawner.spawn_hype(Vector2.ZERO, 0)
	var spawned: Node = _first_floating_child(_court)
	assert_null(spawned,
		"spawn_hype must not spawn a FloatingText when delta is zero")


func test_multiple_simultaneous_stamina_drains_each_produce_independent_text() -> void:
	# Edge case: multiple ballers draining on the same beat get separate texts
	_fake_baller.position = Vector2(10.0, 10.0)
	_fake_baller2.position = Vector2(200.0, 200.0)
	_stamina_system.emit_signal("stamina_changed", _fake_baller, -5)
	_stamina_system.emit_signal("stamina_changed", _fake_baller2, -8)
	await get_tree().process_frame
	var count: int = 0
	for child in _court.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("FloatingText.gd"):
			count += 1
	assert_eq(count, 2,
		"Each independent stamina_changed emission must produce its own FloatingText node")


func test_null_baller_in_stamina_changed_does_not_crash() -> void:
	# Edge case: null baller must be guarded; no crash, no spawn
	_stamina_system.emit_signal("stamina_changed", null, -10)
	await get_tree().process_frame
	# If we reach here without error the guard worked; confirm nothing was spawned
	var spawned: Node = _first_floating_child(_court)
	assert_null(spawned,
		"FloatingTextSpawner must not spawn or crash when baller is null in stamina_changed")


func test_null_baller_in_rebound_won_does_not_crash() -> void:
	# Edge case: null baller in rebound_won must be guarded
	_shot_system.emit_signal("rebound_won", null, null)
	await get_tree().process_frame
	var spawned: Node = _first_floating_child(_court)
	assert_null(spawned,
		"FloatingTextSpawner must not spawn or crash when baller is null in rebound_won")


func test_spawn_with_freed_parent_does_not_crash() -> void:
	# Edge case: if parent (_court) is freed before spawn() is called, must guard gracefully
	var FloatingText := load("res://src/ui/FloatingText.gd")
	var temp_court := Node2D.new()
	add_child(temp_court)
	temp_court.queue_free()
	await get_tree().process_frame  # allow the free to process
	# Calling spawn with a freed parent must not crash
	FloatingText.spawn(temp_court, Vector2.ZERO, "BOOM", Color.WHITE, 16)
	# No assertion needed beyond reaching this line without crashing; add a sentinel
	assert_true(true, "FloatingText.spawn must not crash when the parent has been freed")


# ===========================================================================
# Signal payload validation
# ===========================================================================

func test_stamina_changed_emit_count_is_one_per_drain() -> void:
	# Signal tests: exactly one emission per drain action
	watch_signals(_stamina_system)
	_stamina_system.drain_stamina(_fake_baller, 5)
	assert_signal_emit_count(_stamina_system, "stamina_changed", 1,
		"stamina_changed must be emitted exactly once per drain_stamina call")


func test_stamina_changed_emit_count_is_one_per_recovery() -> void:
	# Signal tests: exactly one emission per recovery action
	watch_signals(_stamina_system)
	_stamina_system.apply_idle_recovery(_fake_baller)
	assert_signal_emit_count(_stamina_system, "stamina_changed", 1,
		"stamina_changed must be emitted exactly once per apply_idle_recovery call")


func test_hype_changed_signal_carries_delta_parameter() -> void:
	# Signal tests: hype_changed must carry a delta parameter (float)
	watch_signals(_hype_manager)
	# Trigger whatever internal action causes hype to change; the signal must include delta
	_hype_manager.add_hype(_fake_baller, 10.0)
	assert_signal_emitted(_hype_manager, "hype_changed",
		"HypeManager must emit hype_changed when hype is added")
	var args: Array = get_signal_parameters(_hype_manager, "hype_changed", 0)
	assert_true(args.size() >= 2,
		"hype_changed signal must carry at least two parameters (baller, delta)")
	assert_true(args[1] is float or args[1] is int,
		"hype_changed delta parameter must be a numeric type")
	assert_gt(args[1], 0,
		"hype_changed delta must be positive when hype is added")
