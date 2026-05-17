extends Node2D
# HypeMilestoneFX — full-court flash + text on hype milestones.
# Child of _court, drawn between guard display and shot arc overlay.

const MILESTONE_TEXT := {
	100: "MOMENTUM!",
	200: "LOCKED IN!",
	300: "ON FIRE!",
	400: "UNSTOPPABLE!",
	500: "MAXIMUM HYPE!",
}

var _alpha: float = 0.0:
	set(value):
		_alpha = value
		queue_redraw()

var _text        : String = ""
var _flash_color : Color  = Color.YELLOW

func _ready() -> void:
	HypeManager.hype_milestone.connect(trigger)

func trigger(level: int) -> void:
	_text        = MILESTONE_TEXT.get(level, "HYPE!")
	_alpha       = 0.65
	_flash_color = Color(1.0, 0.8, 0.1)
	var tween := create_tween()
	tween.tween_property(self, "_alpha", 0.0, 0.6).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	if _alpha <= 0.01:
		return
	var court_w: float = GridManager.GRID_COLS * GridManager.CELL_SIZE
	var court_h: float = GridManager.GRID_ROWS * GridManager.CELL_SIZE
	# Flash fill
	draw_rect(Rect2(0, 0, court_w, court_h),
		Color(_flash_color.r, _flash_color.g, _flash_color.b, _alpha * 0.4))
	# Centered text
	draw_string(ThemeDB.fallback_font,
		Vector2(court_w * 0.5 - 80, court_h * 0.5),
		_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28,
		Color(1.0, 1.0, 1.0, _alpha))
