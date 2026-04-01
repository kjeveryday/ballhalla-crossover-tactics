extends Node2D
# SelectionRing — yellow pulsing ring drawn around the currently selected allied baller.

const RADIUS: float = 30.0
const COLOR  := Color(1.0, 1.0, 0.15, 0.9)

func _draw() -> void:
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, COLOR, 2.5)
	# Small corner tick marks at cardinal points
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var inner := Vector2(cos(angle), sin(angle)) * (RADIUS - 4.0)
		var outer := Vector2(cos(angle), sin(angle)) * (RADIUS + 4.0)
		draw_line(inner, outer, COLOR, 2.0)
