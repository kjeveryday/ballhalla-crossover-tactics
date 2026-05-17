extends "res://entities/baller/Baller.gd"
class_name AlliedBaller
# AlliedBaller — player-controlled baller. Team 0.

const _POS_NAMES := ["PG", "SG", "SF", "PF", "C"]

func _ready() -> void:
	team = 0
	super._ready()
	AlliedTeam.register(self)
	# Redraw on any state change that affects visuals
	BeatManager.beat_started.connect(func(_n): queue_redraw())
	BeatManager.action_committed.connect(func(_a): queue_redraw())
	StaminaSystem.stamina_changed.connect(func(b, _d): if b == self: queue_redraw())
	HypeManager.hype_changed.connect(func(b, _d): if b == self: queue_redraw())

func _process(_delta: float) -> void:
	if has_ball:
		queue_redraw()

func _draw() -> void:
	var half: float = GridManager.CELL_SIZE * 0.4
	var cs: float = GridManager.CELL_SIZE

	# ── Ball carrier glow ring (drawn behind token) ──────────────────────────
	if has_ball:
		var pulse: float = sin(Time.get_ticks_msec() * 0.004) * 0.5 + 0.5
		var alpha: float = 0.55 + pulse * 0.35
		draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 24, Color(1.0, 0.55, 0.0, alpha), 3.0)

	# ── ISO mode dashed ring ─────────────────────────────────────────────────
	if PlayManager.iso_baller == self:
		for i in range(8):
			var start_angle: float = i * TAU / 8.0
			var end_angle: float = start_angle + TAU / 16.0
			draw_arc(Vector2.ZERO, 36.0, start_angle, end_angle, 6,
				Color(1.0, 0.35, 0.0, 0.85), 2.5)

	# ── Token body ───────────────────────────────────────────────────────────
	draw_rect(Rect2(-half, -half, half * 2, half * 2), Color(1.0, 0.6, 0.1))
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

	# ── Acted-this-beat corner fold ──────────────────────────────────────────
	if acted_this_beat:
		var fold: float = 10.0
		draw_line(Vector2(half - fold, -half), Vector2(half, -half + fold),
			Color(0.5, 0.5, 0.55, 0.9), 2.0)

	# ── Exhausted overlay ────────────────────────────────────────────────────
	if is_exhausted:
		draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color(0.0, 0.0, 0.0, 0.55))
		draw_line(Vector2(-half * 0.5, -half * 0.5), Vector2(half * 0.5, half * 0.5),
			Color(0.9, 0.9, 0.9, 0.8), 2.0)
		draw_line(Vector2(half * 0.5, -half * 0.5), Vector2(-half * 0.5, half * 0.5),
			Color(0.9, 0.9, 0.9, 0.8), 2.0)
