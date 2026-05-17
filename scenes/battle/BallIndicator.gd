extends Node2D
# BallIndicator — follows the ball carrier and draws a basketball above them.
# Step 17C adds _override_position to freeze the indicator during pass tweens.
# Must be cleared on: pass_completed, shot_made, shot_missed, turnover_occurred, quarter_ended.

const RADIUS: float = 9.0
const BALL_COLOR    := Color(0.95, 0.50, 0.05)
const SEAM_COLOR    := Color(0.30, 0.14, 0.00)
const OUTLINE_COLOR := Color(0.20, 0.10, 0.00)

# Offset: draw the ball above the baller token
const Y_OFFSET: float = -28.0

# When true, _process does not track the carrier — a tween or manual snap owns position.
# Must be cleared on every possession-end event — see BattleDemo._wire_signals().
var _override_position: bool = false

func clear_override() -> void:
	_override_position = false

# Animate the ball from its current position to target_pos along a parabolic arc.
func tween_to(target_pos: Vector2, duration: float) -> void:
	_override_position = true
	var start := position
	var peak := Vector2((start.x + target_pos.x) * 0.5, min(start.y, target_pos.y) - 40.0)
	var tween := create_tween()
	tween.tween_property(self, "position", peak, duration * 0.5)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position", target_pos, duration * 0.5)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.finished.connect(func(): _override_position = false, CONNECT_ONE_SHOT)

func _process(_delta: float) -> void:
	if _override_position:
		queue_redraw()
		return
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
