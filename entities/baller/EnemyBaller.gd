extends "res://entities/baller/Baller.gd"
class_name EnemyBaller
# EnemyBaller — AI-controlled baller. Team 1.

func _ready() -> void:
	team = 1
	super._ready()
	EnemyTeam.register(self)

const _POS_NAMES := ["PG", "SG", "SF", "PF", "C"]

func _draw() -> void:
	var half: float = GridManager.CELL_SIZE * 0.4
	draw_rect(Rect2(-half, -half, half * 2, half * 2), Color(0.2, 0.6, 1.0))  # blue
	if stats != null:
		draw_string(ThemeDB.fallback_font, Vector2(-half + 2, -half + 12),
			_POS_NAMES[stats.position], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
