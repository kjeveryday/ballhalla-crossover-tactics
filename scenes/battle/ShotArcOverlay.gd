extends Node2D
# ShotArcOverlay — dotted parabolic arc from shooter to rim.
# Drawn in court-space (child of _court). Shown when shoot is chosen, hidden on result.

var _shooter_pos: Vector2 = Vector2.ZERO
var _shooter_col: int = 0
var _active: bool = false

func show_arc(shooter_pos: Vector2, shooter_col: int) -> void:
	_shooter_pos = shooter_pos
	_shooter_col = shooter_col
	_active = true
	queue_redraw()

func hide_arc() -> void:
	_active = false
	queue_redraw()

func _draw() -> void:
	if not _active:
		return
	var rim_pos: Vector2 = GridManager.grid_to_world(_shooter_col, 0)
	var peak: Vector2 = (_shooter_pos + rim_pos) * 0.5 + Vector2(0.0, -96.0)
	for i in range(17):
		var t: float = float(i) / 16.0
		var pt: Vector2 = _quadratic_bezier(_shooter_pos, peak, rim_pos, t)
		var alpha: float = 0.8 - t * 0.4
		draw_circle(pt, 3.0, Color(1.0, 0.9, 0.4, alpha))

func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var mt: float = 1.0 - t
	return mt * mt * p0 + 2.0 * mt * t * p1 + t * t * p2
