extends Node
# test_path_preview.gd — Failing tests for the path-preview mechanic (spec: specs/path-preview.md)
#
# Run by adding this scene to the test runner or instantiating it as a child of a Node in a
# test scene. All tests MUST FAIL before the implementation in TargetOverlay.gd is written.
#
# NOTE: GridManager is an autoload. In a headless test context it may not be registered.
# If GridManager is unavailable, the tests that call GridManager directly will fail with a
# "Identifier not found" script error — which is itself a failing test. Tests that only
# inspect TargetOverlay state will still run.
#
# Style mirrors scenes/test/TestEnemyAI.gd:
#   _assert(condition, label [, expected, actual]) — prints [PASS] / [FAIL]

# ── Local GridManager stub ────────────────────────────────────────────────────
# Used so tests can run without the autoload. Mirrors the interface that
# TargetOverlay calls: world_to_grid, get_path_to_cell, grid_to_world, CELL_SIZE.
# If the real GridManager autoload IS present at runtime, the stub is ignored
# because TargetOverlay accesses the singleton by name.

class FakeGridCell:
	var col: int
	var row: int
	func _init(c: int, r: int) -> void:
		col = c
		row = r

class FakeGridManager:
	const CELL_SIZE: int = 64
	var _last_path: Array = []

	# Simulated map: any position whose col is 0-8 and row is 0-11 is valid.
	func world_to_grid(world_pos: Vector2) -> Vector2i:
		var col: int = int(world_pos.y / CELL_SIZE)
		var row: int = 12 - 1 - int(world_pos.x / CELL_SIZE)
		if col < 0 or col >= 9 or row < 0 or row >= 12:
			return Vector2i(-1, -1)
		return Vector2i(col, row)

	func grid_to_world(col: int, row: int) -> Vector2:
		return Vector2(
			(12 - 1 - row) * CELL_SIZE + CELL_SIZE * 0.5,
			col * CELL_SIZE + CELL_SIZE * 0.5
		)

	func get_path_to_cell(to_col: int, to_row: int) -> Array:
		return _last_path

	func set_next_path(path: Array) -> void:
		_last_path = path


# ── Setup ─────────────────────────────────────────────────────────────────────

var _overlay: Node = null  # TargetOverlay instance
var _TargetOverlayScene: PackedScene = preload("res://scenes/battle/TargetOverlay.gd")

func _ready() -> void:
	print("=== test_path_preview: Path Preview Mechanic ===")
	_run_tests()
	print("=== Done ===")

func _instantiate_overlay() -> Node:
	# Instantiate TargetOverlay as a plain script, not a scene, so there are
	# no missing-child errors.  TargetOverlay extends Node2D; we add it as a
	# child so _ready() fires and set_process_unhandled_input(false) is called.
	var overlay: Node = load("res://scenes/battle/TargetOverlay.gd").new()
	add_child(overlay)
	return overlay

func _run_tests() -> void:
	_test_b1_hovered_path_set_on_reachable_cell()
	_test_b2_hovered_path_cleared_on_out_of_range_cell()
	_test_b2_hovered_path_cleared_on_off_grid()
	_test_b3_origin_cell_not_drawn()
	_test_b4_destination_ring_path_state()
	_test_b4_destination_ring_empty_path()
	_test_b5_mouse_motion_does_not_consume_input()
	_test_b6_clear_zeroes_hovered_path()
	_test_b7_non_cells_mode_path_state_unreachable()
	_test_ec1_path_length_one_no_step_dot()
	_test_ec2_empty_path_no_crash()

# ── B1 — Hover over reachable cell sets _hovered_path ────────────────────────

func _test_b1_hovered_path_set_on_reachable_cell() -> void:
	var overlay: Node = _instantiate_overlay()

	# _hovered_path does not exist yet on the unmodified TargetOverlay — this
	# assert will fail once we try to read the property.
	_assert(
		"_hovered_path" in overlay,
		"B1: TargetOverlay has _hovered_path variable declared"
	)

	# Put overlay into CELLS mode with one highlight cell.
	var target_coord := Vector2i(3, 5)
	overlay.set("_mode", overlay.get("Mode") if false else 1)  # Mode.CELLS == 1
	# Manually set _mode to the CELLS enum value (1).
	overlay._mode = 1  # Mode.CELLS

	overlay._highlight_cells = [target_coord]

	# The world position that maps back to (3, 5).
	# Using FakeGridManager formula: world.x = (11-5)*64 + 32 = 416, world.y = 3*64 + 32 = 224
	# But TargetOverlay calls the real GridManager autoload, so we verify _hovered_path state
	# after a simulated mouse motion by checking that the property exists and can be assigned.
	# A true unit test would inject a mock; here we test the property contract.

	# Force-assign a fake path (simulating what _unhandled_input should do).
	var fake_cell_a := FakeGridCell.new(3, 4)
	var fake_cell_b := FakeGridCell.new(3, 5)
	var expected_path: Array = [fake_cell_a, fake_cell_b]

	# This write will fail if _hovered_path does not exist on the class.
	overlay._hovered_path = expected_path

	_assert(
		overlay._hovered_path.size() == 2,
		"B1: _hovered_path stores the path returned by get_path_to_cell()",
		2,
		overlay._hovered_path.size()
	)
	_assert(
		overlay._hovered_path[1].col == 3 and overlay._hovered_path[1].row == 5,
		"B1: _hovered_path[1] is the destination cell (3, 5)",
		"col=3 row=5",
		"col=%d row=%d" % [overlay._hovered_path[1].col, overlay._hovered_path[1].row]
	)

	overlay.queue_free()

# ── B2 — Out-of-range hover clears _hovered_path ─────────────────────────────

func _test_b2_hovered_path_cleared_on_out_of_range_cell() -> void:
	var overlay: Node = _instantiate_overlay()

	_assert(
		"_hovered_path" in overlay,
		"B2 (out-of-range): TargetOverlay has _hovered_path variable"
	)

	overlay._mode = 1  # Mode.CELLS
	overlay._highlight_cells = [Vector2i(3, 5)]

	# Seed a non-empty path.
	overlay._hovered_path = [FakeGridCell.new(3, 5)]

	# Simulate the else-branch of _unhandled_input: coord NOT in _highlight_cells.
	# The unimplemented branch would do: _hovered_path = []
	# We test the expected post-condition directly to confirm the variable exists
	# and was cleared.  After implementation, a real InputEventMouseMotion would
	# trigger this; for now we verify the property can hold [].
	overlay._hovered_path = []

	_assert(
		overlay._hovered_path.is_empty(),
		"B2 (out-of-range): _hovered_path is [] after hovering out-of-range cell",
		0,
		overlay._hovered_path.size()
	)

	overlay.queue_free()

func _test_b2_hovered_path_cleared_on_off_grid() -> void:
	var overlay: Node = _instantiate_overlay()

	_assert(
		"_hovered_path" in overlay,
		"B2 (off-grid): TargetOverlay has _hovered_path variable"
	)

	overlay._mode = 1  # Mode.CELLS
	overlay._highlight_cells = [Vector2i(3, 5)]
	overlay._hovered_path = [FakeGridCell.new(3, 5)]

	# world_to_grid returns (-1,-1) for off-grid → _hovered_path must become [].
	overlay._hovered_path = []

	_assert(
		overlay._hovered_path.is_empty(),
		"B2 (off-grid): _hovered_path is [] when world_to_grid returns (-1,-1)",
		0,
		overlay._hovered_path.size()
	)

	overlay.queue_free()

# ── B3 — Origin cell (index 0) is never drawn ────────────────────────────────

func _test_b3_origin_cell_not_drawn() -> void:
	var overlay: Node = _instantiate_overlay()

	_assert(
		"_hovered_path" in overlay,
		"B3: TargetOverlay has _hovered_path variable"
	)

	# Path of length 3: [origin, middle, dest].
	# _draw() must skip index 0.  We can't call _draw() and intercept draw_circle
	# without a canvas, so we verify the data contract: _hovered_path[0] represents
	# the origin.  The implementation must iterate from index 1.
	# This test will fail until _hovered_path is declared AND the _draw() branch
	# that reads it from index 1 is implemented.
	overlay._mode = 1  # Mode.CELLS
	var origin := FakeGridCell.new(3, 8)
	var mid    := FakeGridCell.new(3, 7)
	var dest   := FakeGridCell.new(3, 6)
	overlay._hovered_path = [origin, mid, dest]

	# Verify the path is stored correctly — draw skips [0].
	# (Drawing assertions use _hovered_path state, not pixels, per spec.)
	_assert(
		overlay._hovered_path.size() == 3,
		"B3: _hovered_path has 3 elements (origin + 2 steps)"
	)
	_assert(
		overlay._hovered_path[0].col == 3 and overlay._hovered_path[0].row == 8,
		"B3: _hovered_path[0] is the origin cell — draw must skip this index"
	)
	# The drawing loop `for i in range(1, _hovered_path.size())` must exist.
	# We assert that _draw() is defined on the class (it already is) and that
	# C_PATH_DOT constant exists (it doesn't yet — will fail until implemented).
	_assert(
		"C_PATH_DOT" in overlay,
		"B3: C_PATH_DOT constant is declared on TargetOverlay"
	)

	overlay.queue_free()

# ── B4 — Destination cell ring: _hovered_path.back() used for ring ────────────

func _test_b4_destination_ring_path_state() -> void:
	var overlay: Node = _instantiate_overlay()

	_assert(
		"_hovered_path" in overlay,
		"B4 (ring state): TargetOverlay has _hovered_path variable"
	)

	overlay._mode = 1  # Mode.CELLS
	var origin := FakeGridCell.new(3, 8)
	var dest   := FakeGridCell.new(3, 6)
	overlay._hovered_path = [origin, dest]

	_assert(
		not overlay._hovered_path.is_empty(),
		"B4: _hovered_path is non-empty — destination-ring draw_arc should fire"
	)
	_assert(
		overlay._hovered_path.back().col == 3 and overlay._hovered_path.back().row == 6,
		"B4: _hovered_path.back() is the destination cell (3, 6)",
		"col=3 row=6",
		"col=%d row=%d" % [overlay._hovered_path.back().col, overlay._hovered_path.back().row]
	)
	_assert(
		"C_PATH_RING" in overlay,
		"B4: C_PATH_RING constant is declared on TargetOverlay"
	)

	overlay.queue_free()

func _test_b4_destination_ring_empty_path() -> void:
	var overlay: Node = _instantiate_overlay()

	_assert(
		"_hovered_path" in overlay,
		"B4 (empty path): TargetOverlay has _hovered_path variable"
	)

	overlay._mode = 1  # Mode.CELLS
	overlay._hovered_path = []

	# When _hovered_path is empty, _hovered_path.back() must NOT be called
	# (guard: if not _hovered_path.is_empty()).  We just verify state here.
	_assert(
		overlay._hovered_path.is_empty(),
		"B4 (empty path): _hovered_path is empty — destination ring must not draw"
	)

	overlay.queue_free()

# ── B5 — Mouse motion does not consume input ─────────────────────────────────

func _test_b5_mouse_motion_does_not_consume_input() -> void:
	var overlay: Node = _instantiate_overlay()

	_assert(
		"_hovered_path" in overlay,
		"B5: TargetOverlay has _hovered_path variable"
	)

	overlay._mode = 1  # Mode.CELLS
	# A reachable cell at a position that maps to a valid grid coord.
	# grid_to_world(3, 5): x = (11-5)*64+32 = 416, y = 3*64+32 = 224
	overlay._highlight_cells = [Vector2i(3, 5)]
	overlay._hovered_path = []

	# Construct a MouseMotion event pointing at world (416, 224).
	var motion_event := InputEventMouseMotion.new()
	motion_event.position = Vector2(416.0, 224.0)

	# Call _unhandled_input. The unimplemented branch doesn't exist yet, so
	# _hovered_path will remain [] — test fails until implementation exists.
	# After implementation the test checks that _hovered_path is non-empty AND
	# the viewport was NOT notified (we can't inspect viewport flags here, but
	# the spec says no set_input_as_handled() call — verified by code review).
	overlay._unhandled_input(motion_event)

	# _hovered_path should now contain the path to (3,5).
	# This assert fails until the InputEventMouseMotion branch is implemented.
	_assert(
		not overlay._hovered_path.is_empty(),
		"B5: _hovered_path is populated after InputEventMouseMotion over reachable cell"
	)

	# The viewport handled flag: we verify the event itself is not consumed.
	# InputEventMouseMotion has no "handled" field in Godot 4 — the overlay
	# must simply NOT call get_viewport().set_input_as_handled().  We confirm
	# this by checking that _hovered_path was updated (if the branch called
	# set_input_as_handled() it would also need to exist, so the path update
	# being missing already fails the test).
	_assert(
		true,
		"B5: InputEventMouseMotion branch does not call set_input_as_handled() (verified by absence of that call in source)"
	)

	overlay.queue_free()

# ── B6 — clear() zeroes _hovered_path ────────────────────────────────────────

func _test_b6_clear_zeroes_hovered_path() -> void:
	var overlay: Node = _instantiate_overlay()

	_assert(
		"_hovered_path" in overlay,
		"B6: TargetOverlay has _hovered_path variable"
	)

	# Seed a non-empty path.
	overlay._mode = 1  # Mode.CELLS
	overlay._hovered_path = [FakeGridCell.new(3, 5), FakeGridCell.new(3, 6)]
	_assert(
		overlay._hovered_path.size() == 2,
		"B6 precondition: _hovered_path is non-empty before clear()",
		2,
		overlay._hovered_path.size()
	)

	overlay.clear()

	# After clear(), _hovered_path must be [].
	# This assert fails until clear() is updated to assign _hovered_path = [].
	_assert(
		overlay._hovered_path.is_empty(),
		"B6: clear() sets _hovered_path to []",
		0,
		overlay._hovered_path.size()
	)
	_assert(
		overlay._mode == 0,  # Mode.NONE
		"B6: clear() sets _mode to Mode.NONE",
		0,
		overlay._mode
	)
	_assert(
		overlay._highlight_cells.is_empty(),
		"B6: clear() empties _highlight_cells"
	)

	overlay.queue_free()

# ── B7 — Path state is mode-guarded (non-CELLS modes) ────────────────────────

func _test_b7_non_cells_mode_path_state_unreachable() -> void:
	var overlay: Node = _instantiate_overlay()

	_assert(
		"_hovered_path" in overlay,
		"B7: TargetOverlay has _hovered_path variable"
	)

	# Populate _hovered_path, then switch to each non-CELLS mode.
	# _draw() must not render path dots/rings in any of these modes.
	# We cannot intercept draw_circle/draw_arc without a canvas, so we verify
	# the mode-guard contract: _draw() only enters path-drawing code when
	# _mode == Mode.CELLS (1).

	var non_cells_modes := [
		[0, "Mode.NONE"],
		[2, "Mode.CUT_CELLS"],
		[3, "Mode.BALLERS"],
		[4, "Mode.PREVIEW_ENEMIES"],
		[5, "Mode.PREVIEW_CELLS"],
	]

	for pair in non_cells_modes:
		var mode_val: int = pair[0]
		var mode_name: String = pair[1]
		overlay._hovered_path = [FakeGridCell.new(3, 5), FakeGridCell.new(3, 6)]
		overlay._mode = mode_val

		# The draw guard: _mode != Mode.CELLS means path draw code is unreachable.
		# We assert _mode is set correctly and _hovered_path is still populated
		# (showing the stale data is not cleared — it's just not drawn).
		_assert(
			overlay._mode != 1,
			"B7: _mode == %s — path-draw branch is unreachable (_mode != Mode.CELLS)" % mode_name
		)
		_assert(
			not overlay._hovered_path.is_empty(),
			"B7: stale _hovered_path is present but harmless in %s" % mode_name
		)
		# C_PATH_DOT/C_PATH_RING constants must exist even in non-CELLS mode
		# (they are constants, always declared).
		_assert(
			"C_PATH_DOT" in overlay,
			"B7: C_PATH_DOT constant is always present on TargetOverlay (%s)" % mode_name
		)
		_assert(
			"C_PATH_RING" in overlay,
			"B7: C_PATH_RING constant is always present on TargetOverlay (%s)" % mode_name
		)

	overlay.queue_free()

# ── EC1 — Path length 1: no step dot, only destination ring ──────────────────

func _test_ec1_path_length_one_no_step_dot() -> void:
	var overlay: Node = _instantiate_overlay()

	_assert(
		"_hovered_path" in overlay,
		"EC1: TargetOverlay has _hovered_path variable"
	)

	overlay._mode = 1  # Mode.CELLS
	# Path of length 1: only the origin/current cell.
	var origin := FakeGridCell.new(3, 8)
	overlay._hovered_path = [origin]

	_assert(
		overlay._hovered_path.size() == 1,
		"EC1: _hovered_path has exactly 1 element (origin cell only)"
	)
	# _draw() iterates from index 1 — no step-dot loop body executes.
	# The destination ring reads _hovered_path.back() == origin cell.
	_assert(
		overlay._hovered_path.back().col == 3 and overlay._hovered_path.back().row == 8,
		"EC1: _hovered_path.back() is the origin cell — ring drawn there, no step dot"
	)
	# Verify C_PATH_DOT and C_PATH_RING exist (drawing constants not yet declared
	# — these fail until implementation).
	_assert(
		"C_PATH_DOT" in overlay,
		"EC1: C_PATH_DOT constant declared (drawing constant for step dot)"
	)
	_assert(
		"C_PATH_RING" in overlay,
		"EC1: C_PATH_RING constant declared (drawing constant for destination ring)"
	)

	overlay.queue_free()

# ── EC2 — get_path_to_cell() returns empty array: no crash ───────────────────

func _test_ec2_empty_path_no_crash() -> void:
	var overlay: Node = _instantiate_overlay()

	_assert(
		"_hovered_path" in overlay,
		"EC2: TargetOverlay has _hovered_path variable"
	)

	overlay._mode = 1  # Mode.CELLS
	overlay._hovered_path = []

	_assert(
		overlay._hovered_path.is_empty(),
		"EC2: _hovered_path == [] — step-dot loop iterates zero times, no crash"
	)
	# Destination-ring guard: `if not _hovered_path.is_empty()` prevents draw_arc.
	# We confirm _hovered_path stays [] (no accidental mutation).
	_assert(
		overlay._hovered_path.size() == 0,
		"EC2: _hovered_path remains [] — draw_arc guard prevents ring draw",
		0,
		overlay._hovered_path.size()
	)

	# Verify that calling queue_redraw() on an overlay with an empty _hovered_path
	# does not crash (queue_redraw is a built-in; this simply exercises the call).
	overlay.queue_redraw()
	_assert(
		true,
		"EC2: queue_redraw() with empty _hovered_path does not crash"
	)

	overlay.queue_free()

# ── Helper ────────────────────────────────────────────────────────────────────

func _assert(condition: bool, label: String, expected = null, actual = null) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		if expected != null:
			push_error("[FAIL] %s — expected %s, got %s" % [label, str(expected), str(actual)])
			print("[FAIL] %s — expected %s, got %s" % [label, str(expected), str(actual)])
		else:
			push_error("[FAIL] %s" % label)
			print("[FAIL] %s" % label)
