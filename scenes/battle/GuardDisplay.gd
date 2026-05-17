extends Node2D
# GuardDisplay — draws dashed lines between each enemy and their guard assignment.
# Child of _court (below TargetOverlay). Refreshes on beat_started and beat_ended.

func _ready() -> void:
	BeatManager.beat_ended.connect(queue_redraw)
	BeatManager.beat_started.connect(queue_redraw)

func _draw() -> void:
	for enemy in EnemyTeam.get_active_ballers():
		var target: Node = enemy.guard_assignment
		if target == null:
			continue
		_draw_dashed_line(enemy.position, target.position,
			Color(0.45, 0.55, 0.80, 0.55), 1.5, 8.0, 5.0)

func _draw_dashed_line(from: Vector2, to: Vector2,
		color: Color, width: float, dash: float, gap: float) -> void:
	var total: float = from.distance_to(to)
	if total < 0.001:
		return
	var dir: Vector2 = (to - from).normalized()
	var pos: float = 0.0
	while pos < total:
		var end: float = min(pos + dash, total)
		draw_line(from + dir * pos, from + dir * end, color, width)
		pos += dash + gap
