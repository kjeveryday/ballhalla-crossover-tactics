extends Node2D
# TestGrid — Step 1 acceptance criteria verification
# Run this scene to verify all GridManager tests pass.
# Press D to toggle the visual debug zone overlay (via GridOverlay child).

func _ready() -> void:
	_run_tests()

func _run_tests() -> void:
	print("=== TestGrid: Step 1 Acceptance Criteria ===")
	_test_cell_count()
	_test_zone_assignments()
	_test_neighbor_counts()
	_test_distance_to_rim()
	print("=== Tests complete. Press D to toggle zone overlay. ===")

func _test_cell_count() -> void:
	var total := 0
	for c in range(GridManager.GRID_COLS):
		for r in range(GridManager.GRID_ROWS):
			if GridManager.get_cell(c, r) != null:
				total += 1
	if total == 108:
		print("[PASS] Cell count: 108")
	else:
		print("[FAIL] Cell count: expected 108, got %d" % total)

func _test_zone_assignments() -> void:
	var passed := true

	for r in range(9, 12):
		for c in range(GridManager.GRID_COLS):
			if GridManager.get_cell(c, r).zone != GridManager.CourtZone.DEEP:
				print("[FAIL] Zone: (%d,%d) expected DEEP" % [c, r])
				passed = false

	for r in range(7, 9):
		for c in range(GridManager.GRID_COLS):
			if GridManager.get_cell(c, r).zone != GridManager.CourtZone.THREE_POINT:
				print("[FAIL] Zone: (%d,%d) expected THREE_POINT (arc)" % [c, r])
				passed = false

	for r in range(0, 7):
		for c in [0, 8]:
			if GridManager.get_cell(c, r).zone != GridManager.CourtZone.THREE_POINT:
				print("[FAIL] Zone: (%d,%d) expected THREE_POINT (corner)" % [c, r])
				passed = false

	for r in range(0, 3):
		for c in range(3, 6):
			if GridManager.get_cell(c, r).zone != GridManager.CourtZone.PAINT:
				print("[FAIL] Zone: (%d,%d) expected PAINT" % [c, r])
				passed = false

	for r in range(0, 7):
		for c in range(1, 8):
			var cell := GridManager.get_cell(c, r)
			var in_paint: bool = r <= 2 and abs(c - GridManager.CENTER_COL) <= 1
			if not in_paint and cell.zone != GridManager.CourtZone.MIDRANGE:
				print("[FAIL] Zone: (%d,%d) expected MIDRANGE, got %s" % [c, r, GridManager.CourtZone.keys()[cell.zone]])
				passed = false

	if passed:
		print("[PASS] Zone assignments: all 108 cells correct")

func _test_neighbor_counts() -> void:
	var passed := true
	for corner in [[0,0],[8,0],[0,11],[8,11]]:
		var n := GridManager.get_neighbors(corner[0], corner[1]).size()
		if n != 2:
			print("[FAIL] Corner (%d,%d): expected 2 neighbors, got %d" % [corner[0], corner[1], n])
			passed = false
	for edge in [[4,0],[0,5],[8,6],[4,11]]:
		var n := GridManager.get_neighbors(edge[0], edge[1]).size()
		if n != 3:
			print("[FAIL] Edge (%d,%d): expected 3 neighbors, got %d" % [edge[0], edge[1], n])
			passed = false
	var n_interior := GridManager.get_neighbors(4, 5).size()
	if n_interior != 4:
		print("[FAIL] Interior (4,5): expected 4 neighbors, got %d" % n_interior)
		passed = false
	if passed:
		print("[PASS] Neighbor counts: corners=2, edges=3, interior=4")

func _test_distance_to_rim() -> void:
	var passed := true
	if GridManager.distance_to_rim(0) != 0:
		print("[FAIL] distance_to_rim(0): expected 0, got %d" % GridManager.distance_to_rim(0))
		passed = false
	if GridManager.distance_to_rim(11) != 11:
		print("[FAIL] distance_to_rim(11): expected 11, got %d" % GridManager.distance_to_rim(11))
		passed = false
	if GridManager.distance_to_rim(5) != 5:
		print("[FAIL] distance_to_rim(5): expected 5, got %d" % GridManager.distance_to_rim(5))
		passed = false
	if passed:
		print("[PASS] distance_to_rim: 0==0, 5==5, 11==11")
