extends Control
class_name ActionMenu
# ActionMenu — click-driven action panel that appears over the selected allied baller.
# Lives in a CanvasLayer (screen-space). BattleDemo calls show_for_baller() and hide_menu().

signal action_chosen(action_id: String)
signal submenu_action_chosen(action_id: String)

# ── Layout ──────────────────────────────────────
const PANEL_W    := 162
const BTN_H      := 30
const TITLE_H    := 46
const PAD        := 5
const SEP_H      := 6
const MARGIN     := 10  # min distance from screen edge

# ── Colors ──────────────────────────────────────
const C_PANEL_BG   := Color(0.07, 0.07, 0.12, 0.94)
const C_PANEL_BDR  := Color(0.30, 0.45, 0.70, 0.90)
const C_TITLE_BG   := Color(0.12, 0.12, 0.20, 1.00)
const C_BTN_NORM   := Color(0.13, 0.16, 0.25, 0.80)
const C_BTN_HOVER  := Color(0.22, 0.28, 0.45, 0.95)
const C_BTN_PRESS  := Color(0.10, 0.14, 0.22, 1.00)
const C_BTN_DIS    := Color(0.10, 0.10, 0.12, 0.60)
const C_TEXT       := Color(0.92, 0.92, 0.92, 1.00)
const C_TEXT_HOT   := Color(1.00, 0.85, 0.20, 1.00)  # yellow for active plays
const C_TEXT_DIS   := Color(0.38, 0.38, 0.40, 1.00)
const C_SEP        := Color(0.22, 0.28, 0.42, 0.80)

# ── Internal nodes ───────────────────────────────
var _main_panel  : Panel
var _talk_panel  : Panel
var _play_panel  : Panel
var _title_label : Label
var _stats_label : Label
var _main_btns   : Dictionary = {}  # action_id → Button

var _baller: Node = null

# ────────────────────────────────────────────────
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_main_panel()
	_build_talk_panel()
	_build_play_panel()

# ── Public API ───────────────────────────────────

func show_for_baller(baller: Node, screen_pos: Vector2) -> void:
	_baller = baller
	_update_availability()
	_update_title()
	_main_panel.visible = true
	_talk_panel.visible = false
	_play_panel.visible = false
	_position_main_panel(screen_pos)
	visible = true

func hide_menu() -> void:
	visible = false
	_baller = null

func show_talk_sub() -> void:
	_main_panel.visible = false
	_talk_panel.visible = true
	_position_sub_panel(_talk_panel)

func show_play_sub() -> void:
	_main_panel.visible = false
	_play_panel.visible = true
	_position_sub_panel(_play_panel)

# ── Build main panel ─────────────────────────────

func _build_main_panel() -> void:
	_main_panel = _make_panel()
	_main_panel.name = "MainPanel"
	add_child(_main_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(PAD, PAD)
	_main_panel.add_child(vbox)

	# Title block
	var title_bg := ColorRect.new()
	title_bg.color = C_TITLE_BG
	title_bg.custom_minimum_size = Vector2(PANEL_W - PAD * 2, TITLE_H)
	vbox.add_child(title_bg)

	_title_label = Label.new()
	_title_label.position = Vector2(6, 2)
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	title_bg.add_child(_title_label)

	_stats_label = Label.new()
	_stats_label.position = Vector2(6, 20)
	_stats_label.add_theme_font_size_override("font_size", 11)
	_stats_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75))
	title_bg.add_child(_stats_label)

	vbox.add_child(_make_sep())

	# Main action buttons
	var actions := [
		["move",     "Move  ▸",      C_TEXT],
		["pass",     "Pass  ▸",      C_TEXT],
		["shoot",    "Shoot",        C_TEXT],
		["screen",   "Screen",       C_TEXT],
		["talk",     "Talk  ▸",      C_TEXT],
		["playcall", "Play Call  ▸", C_TEXT_HOT],
	]
	for entry in actions:
		var btn := _make_btn(entry[1], entry[0], entry[2])
		vbox.add_child(btn)
		_main_btns[entry[0]] = btn

	vbox.add_child(_make_sep())

	var end_btn := _make_btn("End Turn", "end_turn", C_TEXT)
	vbox.add_child(end_btn)
	_main_btns["end_turn"] = end_btn

	# Fit panel height to content
	var h: float = PAD * 2 + TITLE_H + SEP_H * 2 + actions.size() * (BTN_H + 2) + BTN_H + 2
	_main_panel.custom_minimum_size = Vector2(PANEL_W, h)
	_main_panel.size = Vector2(PANEL_W, h)

# ── Build talk sub-panel ─────────────────────────

func _build_talk_panel() -> void:
	_talk_panel = _make_panel()
	_talk_panel.name = "TalkPanel"
	_talk_panel.visible = false
	add_child(_talk_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(PAD, PAD)
	_talk_panel.add_child(vbox)

	var header := _make_header("Talk")
	vbox.add_child(header)
	vbox.add_child(_make_sep())

	var talk_actions := [
		["trash_talk",  "Trash Talk",    C_TEXT],
		["leadership",  "Leadership  ▸", C_TEXT],
		["iso_talk",    "ISO",           C_TEXT],
	]
	for entry in talk_actions:
		vbox.add_child(_make_sub_btn(entry[1], entry[0], entry[2], false))

	vbox.add_child(_make_sep())
	vbox.add_child(_make_sub_btn("◀ Back", "back_talk", C_TEXT, true))

	var h: float = PAD * 2 + 22 + SEP_H * 2 + talk_actions.size() * (BTN_H + 2) + BTN_H + 2
	_talk_panel.custom_minimum_size = Vector2(PANEL_W, h)
	_talk_panel.size = Vector2(PANEL_W, h)

# ── Build play call sub-panel ────────────────────

func _build_play_panel() -> void:
	_play_panel = _make_panel()
	_play_panel.name = "PlayCallPanel"
	_play_panel.visible = false
	add_child(_play_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(PAD, PAD)
	_play_panel.add_child(vbox)

	var header := _make_header("Play Call")
	vbox.add_child(header)
	vbox.add_child(_make_sep())

	var plays := [
		["play:pick_and_roll",  "Pick & Roll",   C_TEXT_HOT],
		["play:give_and_go",    "Give & Go",     C_TEXT_HOT],
		["play:iso",            "ISO",           C_TEXT_HOT],
		["play:drive_and_kick", "Drive & Kick",  C_TEXT_HOT],
	]
	for entry in plays:
		vbox.add_child(_make_sub_btn(entry[1], entry[0], entry[2], false))

	vbox.add_child(_make_sep())
	vbox.add_child(_make_sub_btn("◀ Back", "back_play", C_TEXT, true))

	var h: float = PAD * 2 + 22 + SEP_H * 2 + plays.size() * (BTN_H + 2) + BTN_H + 2
	_play_panel.custom_minimum_size = Vector2(PANEL_W, h)
	_play_panel.size = Vector2(PANEL_W, h)

# ── Availability + title updates ─────────────────

func _update_availability() -> void:
	if _baller == null:
		return
	var has_ball: bool = _baller.has_ball
	var is_first_action: bool = BeatManager.actions_remaining == BeatManager.ACTIONS_PER_BEAT

	_set_btn_enabled("pass",     has_ball)
	_set_btn_enabled("shoot",    has_ball)
	_set_btn_enabled("playcall", is_first_action)

func _set_btn_enabled(action_id: String, enabled: bool) -> void:
	if not _main_btns.has(action_id):
		return
	var btn: Button = _main_btns[action_id]
	btn.disabled = not enabled
	var tc: Color = C_TEXT_DIS if not enabled else (C_TEXT_HOT if action_id == "playcall" else C_TEXT)
	btn.add_theme_color_override("font_color", tc)
	btn.add_theme_color_override("font_color_disabled", C_TEXT_DIS)

func _update_title() -> void:
	if _baller == null:
		return
	_title_label.text = _baller.stats.display_name
	var zone_name: String = GridManager.CourtZone.keys()[
		GridManager.get_zone(_baller.grid_col, _baller.grid_row)]
	_stats_label.text = "HP %d/%d  Hype %d  [%s]" % [
		_baller.current_stamina, _baller.stats.max_stamina,
		int(_baller.current_hype), zone_name]

# ── Positioning ──────────────────────────────────

func _position_main_panel(screen_pos: Vector2) -> void:
	# Offset to upper-right of the baller token
	var pos := screen_pos + Vector2(28.0, -_main_panel.size.y * 0.5)
	_main_panel.position = _clamped(pos, _main_panel.size)

func _position_sub_panel(panel: Panel) -> void:
	# Appear to the right of the main panel position
	var base := _main_panel.position
	var pos := Vector2(base.x + PANEL_W + 4.0, base.y)
	panel.position = _clamped(pos, panel.size)

func _clamped(pos: Vector2, sz: Vector2) -> Vector2:
	var vp: Vector2 = get_viewport_rect().size
	return Vector2(
		clamp(pos.x, MARGIN, vp.x - sz.x - MARGIN),
		clamp(pos.y, MARGIN, vp.y - sz.y - MARGIN)
	)

# ── Widget factories ─────────────────────────────

func _make_panel() -> Panel:
	var p := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL_BG
	style.border_color = C_PANEL_BDR
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left   = PAD
	style.content_margin_right  = PAD
	style.content_margin_top    = PAD
	style.content_margin_bottom = PAD
	p.add_theme_stylebox_override("panel", style)
	return p

func _make_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 1.0))
	lbl.custom_minimum_size = Vector2(PANEL_W - PAD * 2, 20)
	return lbl

func _make_sep() -> HSeparator:
	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(PANEL_W - PAD * 2, SEP_H)
	var style := StyleBoxFlat.new()
	style.bg_color = C_SEP
	style.content_margin_top = SEP_H * 0.3
	sep.add_theme_stylebox_override("separator", style)
	return sep

func _make_btn(label: String, action_id: String, text_color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(PANEL_W - PAD * 2, BTN_H)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_color_hover", Color.WHITE)
	btn.add_theme_color_override("font_color_pressed", Color(0.8, 0.9, 1.0))
	btn.add_theme_color_override("font_color_disabled", C_TEXT_DIS)
	btn.add_theme_stylebox_override("normal",   _btn_style(C_BTN_NORM))
	btn.add_theme_stylebox_override("hover",    _btn_style(C_BTN_HOVER))
	btn.add_theme_stylebox_override("pressed",  _btn_style(C_BTN_PRESS))
	btn.add_theme_stylebox_override("disabled", _btn_style(C_BTN_DIS))
	btn.pressed.connect(_on_main_pressed.bind(action_id))
	return btn

func _make_sub_btn(label: String, action_id: String, text_color: Color, muted: bool) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(PANEL_W - PAD * 2, BTN_H)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 13)
	var tc: Color = Color(0.6, 0.6, 0.65) if muted else text_color
	btn.add_theme_color_override("font_color", tc)
	btn.add_theme_color_override("font_color_hover", Color.WHITE)
	btn.add_theme_stylebox_override("normal",  _btn_style(C_BTN_NORM))
	btn.add_theme_stylebox_override("hover",   _btn_style(C_BTN_HOVER))
	btn.add_theme_stylebox_override("pressed", _btn_style(C_BTN_PRESS))
	btn.pressed.connect(_on_sub_pressed.bind(action_id))
	return btn

func _btn_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(3)
	s.content_margin_left = 8
	s.content_margin_right = 4
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s

# ── Button handlers ──────────────────────────────

func _on_main_pressed(action_id: String) -> void:
	match action_id:
		"talk":
			show_talk_sub()
		"playcall":
			show_play_sub()
		_:
			action_chosen.emit(action_id)

func _on_sub_pressed(action_id: String) -> void:
	match action_id:
		"back_talk", "back_play":
			_talk_panel.visible = false
			_play_panel.visible = false
			_main_panel.visible = true
		"leadership":
			submenu_action_chosen.emit(action_id)
		_:
			submenu_action_chosen.emit(action_id)
