extends "res://entities/baller/Baller.gd"
class_name EnemyBaller
# EnemyBaller — AI-controlled baller. Team 1.

const _POS_NAMES := ["PG", "SG", "SF", "PF", "C"]

func _ready() -> void:
	team = 1
	super._ready()
	EnemyTeam.register(self)
	BeatManager.beat_started.connect(func(_n): queue_redraw())
	StaminaSystem.stamina_changed.connect(func(b, _d): if b == self: queue_redraw())

func _draw() -> void:
	var half: float = GridManager.CELL_SIZE * 0.4
	var cs: float = GridManager.CELL_SIZE

	# ── Token body ───────────────────────────────────────────────────────────
	draw_rect(Rect2(-half, -half, half * 2, half * 2), Color(0.2, 0.6, 1.0))
	if stats != null:
		draw_string(ThemeDB.fallback_font, Vector2(-half + 2, -half + 12),
			_POS_NAMES[stats.position], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

	# ── Stamina mini-bar ─────────────────────────────────────────────────────
	var bar_w: float = cs * 0.70
	var bar_h: float = 4.0
	var bar_x: float = -bar_w * 0.5
	var bar_y: float = cs * 0.38
	var pct: float = float(current_stamina) / float(stats.max_stamina) if stats else 1.0
	var bar_color: Color
	if pct > 0.60:
		bar_color = Color(0.20, 0.85, 0.30)
	elif pct > 0.30:
		bar_color = Color(0.95, 0.80, 0.10)
	else:
		bar_color = Color(0.90, 0.20, 0.15)
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(bar_x, bar_y, bar_w * pct, bar_h), bar_color)

	# ── Exhausted overlay ────────────────────────────────────────────────────
	if is_exhausted:
		draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color(0.0, 0.0, 0.0, 0.55))
		draw_line(Vector2(-half * 0.5, -half * 0.5), Vector2(half * 0.5, half * 0.5),
			Color(0.9, 0.9, 0.9, 0.8), 2.0)
		draw_line(Vector2(half * 0.5, -half * 0.5), Vector2(-half * 0.5, half * 0.5),
			Color(0.9, 0.9, 0.9, 0.8), 2.0)
