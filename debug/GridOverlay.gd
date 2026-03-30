extends Node2D
# GridOverlay — reusable debug grid with zone colors.
# Instance this as a child in any test scene. Press D to toggle.

const ZONE_COLORS := {
	GridManager.CourtZone.PAINT:       Color(1.0, 0.3, 0.3, 0.5),
	GridManager.CourtZone.MIDRANGE:    Color(1.0, 0.85, 0.2, 0.4),
	GridManager.CourtZone.THREE_POINT: Color(0.3, 0.8, 0.3, 0.5),
	GridManager.CourtZone.DEEP:        Color(0.3, 0.5, 1.0, 0.4),
}

var _show_overlay: bool = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_D:
		_show_overlay = not _show_overlay
		queue_redraw()
		print("[DEBUG] Zone overlay: %s" % ("ON" if _show_overlay else "OFF"))

func _draw() -> void:
	if not _show_overlay:
		return
	for c in range(GridManager.GRID_COLS):
		for r in range(GridManager.GRID_ROWS):
			var cell := GridManager.get_cell(c, r)
			if cell == null:
				continue
			var rect := Rect2(
				(GridManager.GRID_ROWS - 1 - r) * GridManager.CELL_SIZE,
				c * GridManager.CELL_SIZE,
				GridManager.CELL_SIZE,
				GridManager.CELL_SIZE
			)
			draw_rect(rect, ZONE_COLORS.get(cell.zone, Color.WHITE))
			draw_rect(rect, Color(0, 0, 0, 0.3), false, 1.0)
