extends Node
# GridManager — Autoload
# Manages the 9x12 battle grid, zone assignments, and spatial queries.
# Register as autoload #2 in Project Settings (after GameStateMachine).

const GRID_COLS: int = 9
const GRID_ROWS: int = 12
const CELL_SIZE: int = 64
const RIM_ROW: int = 0
const CENTER_COL: int = 4  # center of GRID_COLS (9)

# Zone boundaries (column-based)
const PAINT_HALF_WIDTH: int = 1        # cols 3,4,5 (center ± 1)
const CORNER_THREE_COL_MIN: int = 0    # col 0  = one sideline corner
const CORNER_THREE_COL_MAX: int = 8    # col 8  = other sideline corner

# Zone boundaries (row-based)
const PAINT_ROW_MAX: int = 2           # rows 0-2 are paint depth
const THREE_PT_ROW_MIN: int = 7        # rows 7-8 are the arc
const DEEP_ROW_MIN: int = 9            # rows 9-11 are deep

enum CourtZone {
	PAINT,        # Center 3 cols (3,4,5), rows 0–2
	MIDRANGE,     # Inside the arc, outside the paint
	THREE_POINT,  # Arc (rows 7–8) and corner sidelines (col 0 or 8, rows 0–6)
	DEEP,         # rows 9–11
}

class GridCell:
	var col: int
	var row: int
	var zone: CourtZone
	var occupant = null        # Baller node or null
	var is_out_of_bounds: bool = false

	func _init(c: int, r: int, z: CourtZone) -> void:
		col = c
		row = r
		zone = z

var _grid: Array = []  # [col][row] -> GridCell

func _ready() -> void:
	_initialize_grid()

func _initialize_grid() -> void:
	_grid = []
	for c in range(GRID_COLS):
		var col_array: Array = []
		for r in range(GRID_ROWS):
			col_array.append(GridCell.new(c, r, get_zone(c, r)))
		_grid.append(col_array)
	if OS.is_debug_build():
		print("[GRID] Initialized %d cells (%dx%d)" % [GRID_COLS * GRID_ROWS, GRID_COLS, GRID_ROWS])

func get_zone(col: int, row: int) -> CourtZone:  # Returns CourtZone for the given cell
	# Deep: beyond the arc entirely
	if row >= DEEP_ROW_MIN:
		return CourtZone.DEEP

	# Three-point arc: rows 7-8, full width
	if row >= THREE_PT_ROW_MIN:
		return CourtZone.THREE_POINT

	# Corner threes: sideline columns (col 0 or col 8) within arc distance
	if col == CORNER_THREE_COL_MIN or col == CORNER_THREE_COL_MAX:
		return CourtZone.THREE_POINT

	# Paint: center 3 columns (cols 3,4,5) within 3 rows of hoop
	if row <= PAINT_ROW_MAX and abs(col - CENTER_COL) <= PAINT_HALF_WIDTH:
		return CourtZone.PAINT

	# Everything else is mid-range
	return CourtZone.MIDRANGE

func get_cell(col: int, row: int) -> GridCell:  # null if OOB
	if col < 0 or col >= GRID_COLS or row < 0 or row >= GRID_ROWS:
		return null
	return _grid[col][row]

func get_neighbors(col: int, row: int) -> Array[GridCell]:  # 4-directional
	var neighbors: Array[GridCell] = []
	var directions := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for dir in directions:
		var cell := get_cell(col + dir.x, row + dir.y)
		if cell != null:
			neighbors.append(cell)
	return neighbors

func get_cells_in_range(col: int, row: int, steps: int) -> Array[GridCell]:  # BFS
	var result: Array[GridCell] = []
	var visited: Dictionary = {}
	var queue: Array = []

	visited[Vector2i(col, row)] = true
	queue.append([col, row, 0])

	while not queue.is_empty():
		var current = queue.pop_front()
		var c: int = current[0]
		var r: int = current[1]
		var dist: int = current[2]

		if dist > 0:
			var cell := get_cell(c, r)
			if cell != null:
				result.append(cell)

		if dist < steps:
			for neighbor in get_neighbors(c, r):
				var key := Vector2i(neighbor.col, neighbor.row)
				if not visited.has(key):
					visited[key] = true
					queue.append([neighbor.col, neighbor.row, dist + 1])

	return result

func distance_to_rim(row: int) -> int:  # Manhattan to row 0 (rim is at row 0)
	return row

func grid_to_world(col: int, row: int) -> Vector2:  # Center of a grid cell in world space
	return Vector2(
		(GRID_ROWS - 1 - row) * CELL_SIZE + CELL_SIZE * 0.5,
		col * CELL_SIZE + CELL_SIZE * 0.5
	)

func world_to_grid(world_pos: Vector2) -> Vector2i:  # World pos → (col, row), (-1,-1) if OOB
	var col: int = int(world_pos.y / CELL_SIZE)
	var row: int = GRID_ROWS - 1 - int(world_pos.x / CELL_SIZE)
	if col < 0 or col >= GRID_COLS or row < 0 or row >= GRID_ROWS:
		return Vector2i(-1, -1)
	return Vector2i(col, row)
