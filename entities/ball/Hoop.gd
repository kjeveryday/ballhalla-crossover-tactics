class_name Hoop extends Node2D
# Hoop — static anchor at row 0, col 4 (center of the rim row).
# Queryable from anywhere via group "hoop".
# Referenced by distance calculations and shot resolution.

const HOOP_COL: int = 4
const HOOP_ROW: int = 0

func _ready() -> void:
	add_to_group("hoop")
	_update_visual_position()

func get_grid_position() -> Vector2i:
	return Vector2i(HOOP_COL, HOOP_ROW)

func _update_visual_position() -> void:
	# Match the GridOverlay coordinate system: hoop on the right, row 0 = rightmost
	position = Vector2(
		(GridManager.GRID_ROWS - 1 - HOOP_ROW) * GridManager.CELL_SIZE + GridManager.CELL_SIZE * 0.5,
		HOOP_COL * GridManager.CELL_SIZE + GridManager.CELL_SIZE * 0.5
	)
