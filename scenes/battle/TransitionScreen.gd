extends Control
# TransitionScreen — full-screen modal for defense results, quarter breaks, halftime choice.
# Added last to HUD CanvasLayer so it renders above everything.
# Blocks all input underneath via MOUSE_FILTER_STOP.

const SCREEN_W := 816.0
const SCREEN_H := 716.0
const PANEL_W  := 480.0
const PANEL_H  := 340.0
const PANEL_X  := (SCREEN_W - PANEL_W) * 0.5   # 168.0
const PANEL_Y  := (SCREEN_H - PANEL_H) * 0.5   # 188.0

const C_DIM      := Color(0.04, 0.04, 0.08, 0.88)
const C_BG       := Color(0.09, 0.09, 0.14, 0.97)
const C_BDR      := Color(0.30, 0.35, 0.55, 0.80)
const C_SEP      := Color(0.35, 0.35, 0.50, 0.50)
const C_TITLE    := Color(0.95, 0.95, 0.95, 1.00)
const C_GOLD     := Color(1.00, 0.80, 0.20, 1.00)
const C_STEEL    := Color(0.70, 0.78, 0.90, 1.00)
const C_TEXT     := Color(0.82, 0.82, 0.82, 1.00)
const C_DIM_TXT  := Color(0.55, 0.55, 0.60, 1.00)
const C_GOOD     := Color(0.25, 0.85, 0.35, 1.00)
const C_BAD      := Color(0.90, 0.25, 0.20, 1.00)

enum Mode { NONE, DEFENSE, QUARTER_END, HALFTIME }

var _mode: Mode = Mode.NONE

# Defense mode cached data
var _def_scored: bool = false
var _def_points: int = 0
var _def_eo: float = 0.0
var _def_ad: float = 0.0
var _def_sf: float = 0.0

# Quarter/halftime shared data
var _q_num: int = 0
var _q_allied: int = 0
var _q_enemy: int = 0
var _q_stats: Dictionary = {}  # { display_name: { pts, ast, scr } }

var _continue_btn: Button
var _rest_btn: Button
var _play_btn: Button

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(SCREEN_W, SCREEN_H)
	visible = false

	_continue_btn = _make_btn("CONTINUE")
	_continue_btn.position = Vector2(PANEL_X + (PANEL_W - 160.0) * 0.5, PANEL_Y + PANEL_H - 54.0)
	_continue_btn.pressed.connect(_on_continue)
	add_child(_continue_btn)

	_rest_btn = _make_btn("REST TEAM")
	_rest_btn.position = Vector2(PANEL_X + 48.0, PANEL_Y + PANEL_H - 96.0)
	_rest_btn.pressed.connect(func(): _on_halftime_choice("rest_team"))
	add_child(_rest_btn)

	_play_btn = _make_btn("CALL THE PLAY")
	_play_btn.position = Vector2(PANEL_X + PANEL_W - 48.0 - 160.0, PANEL_Y + PANEL_H - 96.0)
	_play_btn.pressed.connect(func(): _on_halftime_choice("call_play"))
	add_child(_play_btn)

	_continue_btn.visible = false
	_rest_btn.visible = false
	_play_btn.visible = false

# ─────────────────────────────────────────────
#  Public API
# ─────────────────────────────────────────────

func show_defense_result(scored: bool, points: int,
		enemy_offense: float, allied_defense: float, stamina_factor: float) -> void:
	_mode = Mode.DEFENSE
	_def_scored = scored
	_def_points = points
	_def_eo = enemy_offense
	_def_ad = allied_defense
	_def_sf = stamina_factor
	_continue_btn.visible = true
	_rest_btn.visible = false
	_play_btn.visible = false
	visible = true
	queue_redraw()

func show_quarter_end(quarter: int, allied: int, enemy: int, stats: Dictionary) -> void:
	_mode = Mode.QUARTER_END
	_q_num = quarter
	_q_allied = allied
	_q_enemy = enemy
	_q_stats = stats.duplicate()
	_continue_btn.visible = true
	_rest_btn.visible = false
	_play_btn.visible = false
	visible = true
	queue_redraw()

func show_halftime(allied: int, enemy: int) -> void:
	_mode = Mode.HALFTIME
	_q_allied = allied
	_q_enemy = enemy
	_continue_btn.visible = false
	_rest_btn.visible = true
	_play_btn.visible = true
	visible = true
	queue_redraw()

# ─────────────────────────────────────────────
#  Internal handlers
# ─────────────────────────────────────────────

func _on_continue() -> void:
	visible = false
	QuarterManager.continue_flow()

func _on_halftime_choice(choice: String) -> void:
	visible = false
	QuarterManager.apply_halftime_choice(choice)

# ─────────────────────────────────────────────
#  Drawing
# ─────────────────────────────────────────────

func _draw() -> void:
	if _mode == Mode.NONE:
		return
	var font := ThemeDB.fallback_font
	# Full-screen dim
	draw_rect(Rect2(0.0, 0.0, SCREEN_W, SCREEN_H), C_DIM)
	# Panel
	draw_rect(Rect2(PANEL_X, PANEL_Y, PANEL_W, PANEL_H), C_BG)
	draw_rect(Rect2(PANEL_X, PANEL_Y, PANEL_W, PANEL_H), C_BDR, false, 1.5)
	match _mode:
		Mode.DEFENSE:    _draw_defense(font)
		Mode.QUARTER_END: _draw_quarter_end(font)
		Mode.HALFTIME:   _draw_halftime(font)

func _draw_defense(font: Font) -> void:
	var y := PANEL_Y + 32.0

	# Title
	draw_string(font, Vector2(PANEL_X, y), "DEFENSE PHASE",
		HORIZONTAL_ALIGNMENT_CENTER, PANEL_W, 20, C_STEEL)
	y += 28.0
	_sep(y)
	y += 16.0

	var col1 := PANEL_X + 48.0
	var col2 := PANEL_X + 240.0

	draw_string(font, Vector2(col1, y), "Enemy Offense:",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_DIM_TXT)
	draw_string(font, Vector2(col2, y), "%.0f" % _def_eo,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_TEXT)
	y += 22.0

	draw_string(font, Vector2(col1, y), "Allied Defense:",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_DIM_TXT)
	draw_string(font, Vector2(col2, y), "%.0f  (×%.0f%% stamina)" % [_def_ad, _def_sf * 100],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_TEXT)
	y += 22.0

	_sep(y)
	y += 16.0

	var threshold: float = clamp((_def_eo - _def_ad * _def_sf) / 100.0, 0.1, 0.9)
	draw_string(font, Vector2(col1, y), "Score chance:",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_DIM_TXT)
	draw_string(font, Vector2(col2, y), "%.0f%%" % (threshold * 100),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_TEXT)
	y += 22.0

	_sep(y)
	y += 22.0

	if _def_scored:
		draw_string(font, Vector2(PANEL_X, y), "ENEMY SCORES %d!" % _def_points,
			HORIZONTAL_ALIGNMENT_CENTER, PANEL_W, 20, C_BAD)
	else:
		draw_string(font, Vector2(PANEL_X, y), "ALLIED HOLDS!",
			HORIZONTAL_ALIGNMENT_CENTER, PANEL_W, 20, C_GOOD)

func _draw_quarter_end(font: Font) -> void:
	var y := PANEL_Y + 32.0

	draw_string(font, Vector2(PANEL_X, y), "END OF QUARTER %d" % _q_num,
		HORIZONTAL_ALIGNMENT_CENTER, PANEL_W, 20, C_TITLE)
	y += 28.0
	_sep(y)
	y += 14.0

	draw_string(font, Vector2(PANEL_X, y),
		"Allied %d  —  Enemy %d" % [_q_allied, _q_enemy],
		HORIZONTAL_ALIGNMENT_CENTER, PANEL_W, 15, C_GOLD)
	y += 22.0
	_sep(y)
	y += 14.0

	var col_name := PANEL_X + 24.0
	var col_pts  := PANEL_X + 216.0
	var col_ast  := PANEL_X + 290.0
	var col_scr  := PANEL_X + 364.0

	# Header row
	draw_string(font, Vector2(col_pts, y),  "PTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_DIM_TXT)
	draw_string(font, Vector2(col_ast, y),  "AST", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_DIM_TXT)
	draw_string(font, Vector2(col_scr, y),  "SCR", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_DIM_TXT)
	y += 18.0

	for name in _q_stats.keys():
		var s: Dictionary = _q_stats[name]
		draw_string(font, Vector2(col_name, y), name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_TEXT)
		draw_string(font, Vector2(col_pts, y), str(s.get("pts", 0)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_TEXT)
		draw_string(font, Vector2(col_ast, y), str(s.get("ast", 0)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_TEXT)
		draw_string(font, Vector2(col_scr, y), str(s.get("scr", 0)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_TEXT)
		y += 18.0

func _draw_halftime(font: Font) -> void:
	var y := PANEL_Y + 34.0

	draw_string(font, Vector2(PANEL_X, y), "HALFTIME",
		HORIZONTAL_ALIGNMENT_CENTER, PANEL_W, 22, C_GOLD)
	y += 32.0
	_sep(y)
	y += 14.0

	draw_string(font, Vector2(PANEL_X, y),
		"Allied %d  —  Enemy %d" % [_q_allied, _q_enemy],
		HORIZONTAL_ALIGNMENT_CENTER, PANEL_W, 15, C_GOLD)
	y += 22.0
	_sep(y)
	y += 18.0

	draw_string(font, Vector2(PANEL_X + 48.0, y), "Choose a halftime adjustment:",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_TEXT)
	y += 40.0

	# Descriptions above the buttons
	var rest_x := PANEL_X + 48.0
	var play_x := PANEL_X + PANEL_W - 48.0 - 160.0
	draw_string(font, Vector2(rest_x, y), "All ballers recover",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_DIM_TXT)
	draw_string(font, Vector2(play_x, y), "Pick & Roll activates",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_DIM_TXT)
	y += 14.0
	draw_string(font, Vector2(rest_x, y), "full stamina",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_DIM_TXT)
	draw_string(font, Vector2(play_x, y), "automatically next possession",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_DIM_TXT)

func _sep(y: float) -> void:
	draw_line(Vector2(PANEL_X + 20.0, y), Vector2(PANEL_X + PANEL_W - 20.0, y), C_SEP, 1.0)

# ─────────────────────────────────────────────
#  Button factory
# ─────────────────────────────────────────────

func _make_btn(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(160.0, 36.0)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.90, 0.92, 0.98))
	btn.add_theme_color_override("font_color_hover", Color(1.0, 1.0, 1.0))
	var s_norm := StyleBoxFlat.new()
	s_norm.bg_color = Color(0.15, 0.22, 0.38)
	s_norm.set_corner_radius_all(5)
	s_norm.border_width_top = 1
	s_norm.border_width_right = 1
	s_norm.border_width_bottom = 1
	s_norm.border_width_left = 1
	s_norm.border_color = Color(0.30, 0.40, 0.60, 0.70)
	btn.add_theme_stylebox_override("normal", s_norm)
	var s_hover: StyleBoxFlat = s_norm.duplicate()
	s_hover.bg_color = Color(0.22, 0.32, 0.52)
	btn.add_theme_stylebox_override("hover", s_hover)
	return btn
