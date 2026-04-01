extends Node2D
# ShotClockBar — 24 blocks across the top. Drains left-to-right as time elapses.
# Beat groups (3 blocks each) are divided by thick separators.
# Current beat's group is highlighted yellow.

const BLOCK_W: int = 31
const BLOCK_H: int = 28
const GAP: int = 1
const LABEL_Y: int = 3    # beat number label above blocks

var _seconds: int = 24

func _ready() -> void:
	ShotClock.clock_updated.connect(_on_clock_updated)
	BeatManager.beat_started.connect(_on_beat_changed)
	BeatManager.beat_ended.connect(_on_beat_changed)

func _on_clock_updated(seconds: int) -> void:
	_seconds = seconds
	queue_redraw()

func _on_beat_changed(_n) -> void:
	queue_redraw()

func _draw() -> void:
	# threshold = how many blocks (from left) have gone dark
	var threshold: int = 24 - _seconds
	var current_beat: int = BeatManager.current_beat

	for i in range(24):
		var bx: int = i * (BLOCK_W + GAP)
		var rect := Rect2(bx, LABEL_Y + 10, BLOCK_W, BLOCK_H)
		var active: bool = i >= threshold
		var beat_group: int = int(float(i) / 3.0) + 1  # which beat (1-8) this block belongs to

		var bg: Color
		if active:
			if _seconds <= 6:
				bg = Color(0.9, 0.15, 0.1)    # urgent red
			elif beat_group == current_beat:
				bg = Color(1.0, 0.85, 0.1)    # current beat: bright yellow
			else:
				bg = Color(0.85, 0.55, 0.05)  # normal: orange
		else:
			bg = Color(0.18, 0.18, 0.18)      # elapsed: dark

		draw_rect(rect, bg)
		draw_rect(rect, Color(0, 0, 0, 0.7), false, 1.0)

	# Beat group separators (thick vertical lines)
	for b in range(1, 8):
		var sx: int = b * 3 * (BLOCK_W + GAP) - 1
		draw_line(Vector2(sx, LABEL_Y + 8), Vector2(sx, LABEL_Y + 10 + BLOCK_H + 2),
			Color.BLACK, 2.5)

	# Beat number labels above each group
	for b in range(8):
		var gx: float = b * 3 * (BLOCK_W + GAP) + (3 * (BLOCK_W + GAP)) * 0.5 - 6.0
		var is_current: bool = (b + 1) == current_beat
		var lc: Color = Color.YELLOW if is_current else Color(0.55, 0.55, 0.55)
		draw_string(ThemeDB.fallback_font, Vector2(gx, LABEL_Y + 8),
			"B%d" % (b + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, lc)

	# Seconds remaining label on the right
	draw_string(ThemeDB.fallback_font,
		Vector2(24 * (BLOCK_W + GAP) + 6, LABEL_Y + 10 + BLOCK_H * 0.75),
		"%ds" % _seconds, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
