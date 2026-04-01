extends Node2D
# BallIndicator — follows the ball carrier and draws a basketball above them.

const RADIUS: float = 9.0
const BALL_COLOR    := Color(0.95, 0.50, 0.05)
const SEAM_COLOR    := Color(0.30, 0.14, 0.00)
const OUTLINE_COLOR := Color(0.20, 0.10, 0.00)

# Offset: draw the ball above the baller token
const Y_OFFSET: float = -28.0

func _process(_delta: float) -> void:
	var carrier: Node = AlliedTeam.get_ball_carrier()
	if carrier != null:
		position = carrier.position + Vector2(0.0, Y_OFFSET)
		visible = true
	else:
		visible = false
	queue_redraw()

func _draw() -> void:
	# Fill
	draw_circle(Vector2.ZERO, RADIUS, BALL_COLOR)
	# Outline
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, OUTLINE_COLOR, 1.5)
	# Horizontal seam
	draw_line(Vector2(-RADIUS, 0), Vector2(RADIUS, 0), SEAM_COLOR, 1.0)
	# Left curve seam
	draw_arc(Vector2(-3.0, 0), RADIUS * 0.55, -PI * 0.45, PI * 0.45, 8, SEAM_COLOR, 1.0)
	# Right curve seam
	draw_arc(Vector2(3.0, 0), RADIUS * 0.55, PI - PI * 0.45, PI + PI * 0.45, 8, SEAM_COLOR, 1.0)
