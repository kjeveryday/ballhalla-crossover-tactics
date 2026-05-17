extends Node2D
# CourtGrid — always-visible cell borders so the grid is readable at all times.
# Drawn before ballers/overlays so it sits at the bottom of the court layer stack.

func _draw() -> void:
	var cs: float = GridManager.CELL_SIZE
	var border := Color(1.0, 1.0, 1.0, 0.10)
	for c in range(GridManager.GRID_COLS):
		for r in range(GridManager.GRID_ROWS):
			var world := GridManager.grid_to_world(c, r)
			draw_rect(
				Rect2(world.x - cs * 0.5, world.y - cs * 0.5, cs, cs),
				border, false, 1.0)
