extends Control
class_name EnemyInfoPanel
# EnemyInfoPanel — read-only info panel for clicked enemy tokens.
# Styled to match ActionMenu. Lives in HUD CanvasLayer.

signal closed()

# ── Shared style constants (match ActionMenu) ────────────────────────────────
const PANEL_W     := 180
const PAD         := 5
const MARGIN      := 10
const C_PANEL_BG  := Color(0.07, 0.07, 0.12, 0.94)
const C_PANEL_BDR := Color(0.50, 0.30, 0.30, 0.90)  # red-tinted border for enemies
const C_TITLE_BG  := Color(0.15, 0.08, 0.08, 1.00)
const C_SEP       := Color(0.42, 0.28, 0.28, 0.80)
const C_TEXT      := Color(0.92, 0.92, 0.92, 1.00)
const C_TEXT_DIM  := Color(0.60, 0.60, 0.65, 1.00)
const C_BAR_BG    := Color(0.15, 0.15, 0.15, 1.00)

# ── Internal nodes ────────────────────────────────────────────────────────────
var _panel: Panel
var _name_label: Label
var _zone_label: Label
var _stam_fill: ColorRect
var _stam_label: Label
var _guard_label: Label
var _off_label: Label
var _def_label: Label
var _resist_label: Label

var _enemy: Node = null

const BAR_W := 100.0
const BAR_H := 5.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_panel()

# ── Public API ────────────────────────────────────────────────────────────────

func show_for_enemy(enemy: Node, screen_pos: Vector2) -> void:
	_enemy = enemy
	_refresh()
	_position_panel(screen_pos)
	visible = true

func hide_panel() -> void:
	visible = false
	_enemy = null

# ── Build ─────────────────────────────────────────────────────────────────────

func _build_panel() -> void:
	_panel = _make_panel()
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(PAD, PAD)
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	# Title block
	var title_bg := ColorRect.new()
	title_bg.color = C_TITLE_BG
	title_bg.custom_minimum_size = Vector2(PANEL_W - PAD * 2, 42)
	vbox.add_child(title_bg)

	_name_label = Label.new()
	_name_label.position = Vector2(6, 2)
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.65))
	title_bg.add_child(_name_label)

	_zone_label = Label.new()
	_zone_label.position = Vector2(6, 20)
	_zone_label.add_theme_font_size_override("font_size", 10)
	_zone_label.add_theme_color_override("font_color", C_TEXT_DIM)
	title_bg.add_child(_zone_label)

	vbox.add_child(_make_sep())

	# Stamina bar row
	var stam_row := _make_row_container()
	vbox.add_child(stam_row)

	var stam_lbl := _make_dim_label("STM")
	stam_row.add_child(stam_lbl)

	var bar_bg := ColorRect.new()
	bar_bg.color = C_BAR_BG
	bar_bg.custom_minimum_size = Vector2(BAR_W, BAR_H)
	stam_row.add_child(bar_bg)

	_stam_fill = ColorRect.new()
	_stam_fill.color = Color(0.20, 0.85, 0.30)
	_stam_fill.position = Vector2.ZERO
	_stam_fill.size = Vector2(BAR_W, BAR_H)
	bar_bg.add_child(_stam_fill)

	_stam_label = Label.new()
	_stam_label.add_theme_font_size_override("font_size", 10)
	_stam_label.add_theme_color_override("font_color", C_TEXT_DIM)
	stam_row.add_child(_stam_label)

	vbox.add_child(_make_sep())

	# Stat rows
	_guard_label  = _make_stat_label()
	_off_label    = _make_stat_label()
	_def_label    = _make_stat_label()
	_resist_label = _make_stat_label()
	vbox.add_child(_guard_label)
	vbox.add_child(_off_label)
	vbox.add_child(_def_label)
	vbox.add_child(_resist_label)

	vbox.add_child(_make_sep())

	# Close button
	var close_btn := Button.new()
	close_btn.text = "× Close"
	close_btn.custom_minimum_size = Vector2(PANEL_W - PAD * 2, 26)
	close_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.add_theme_color_override("font_color", C_TEXT_DIM)
	close_btn.add_theme_color_override("font_color_hover", Color.WHITE)
	close_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.13, 0.16, 0.25, 0.80)))
	close_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.30, 0.18, 0.18, 0.95)))
	close_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.10, 0.10, 0.12, 1.00)))
	close_btn.pressed.connect(_on_close_pressed)
	vbox.add_child(close_btn)

	# Fit panel height
	var total_rows := 5  # guard, off, def, resist + spacing
	var h: float = PAD * 2 + 42 + 6 + BAR_H + 12 + 6 + total_rows * 18 + 6 + 26
	_panel.custom_minimum_size = Vector2(PANEL_W, h)
	_panel.size = Vector2(PANEL_W, h)

# ── Refresh ───────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if _enemy == null or _enemy.stats == null:
		return

	_name_label.text = _enemy.stats.display_name
	var zone_name: String = GridManager.CourtZone.keys()[
		GridManager.get_zone(_enemy.grid_col, _enemy.grid_row)]
	_zone_label.text = "Zone: %s" % zone_name

	# Stamina bar
	var pct: float = float(_enemy.current_stamina) / float(_enemy.stats.max_stamina)
	_stam_fill.size = Vector2(BAR_W * pct, BAR_H)
	if pct > 0.60:
		_stam_fill.color = Color(0.20, 0.85, 0.30)
	elif pct > 0.30:
		_stam_fill.color = Color(0.95, 0.80, 0.10)
	else:
		_stam_fill.color = Color(0.90, 0.20, 0.15)
	_stam_label.text = " %d/%d" % [_enemy.current_stamina, _enemy.stats.max_stamina]

	# Guard assignment
	var guard_name: String = "Unassigned"
	if _enemy.guard_assignment != null and _enemy.guard_assignment.stats != null:
		guard_name = _enemy.guard_assignment.stats.display_name
	_guard_label.text = "Guards: %s" % guard_name

	_off_label.text = "Off Rating: %d" % _enemy.stats.offensive_rating
	_def_label.text = "Def Rating: %d" % _enemy.stats.defensive_rating

	var resist: String
	if _enemy.stats.defensive_rating >= 65:
		resist = "high"
	elif _enemy.stats.defensive_rating >= 40:
		resist = "medium"
	else:
		resist = "low"
	_resist_label.text = "Hype Resist: %s" % resist

# ── Positioning ───────────────────────────────────────────────────────────────

func _position_panel(screen_pos: Vector2) -> void:
	var pos := screen_pos + Vector2(28.0, -_panel.size.y * 0.5)
	_panel.position = _clamped(pos, _panel.size)

func _clamped(pos: Vector2, sz: Vector2) -> Vector2:
	var vp: Vector2 = get_viewport_rect().size
	return Vector2(
		clamp(pos.x, MARGIN, vp.x - sz.x - MARGIN),
		clamp(pos.y, MARGIN, vp.y - sz.y - MARGIN)
	)

# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		hide_panel()
		closed.emit()

# ── Widget factories ──────────────────────────────────────────────────────────

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

func _make_sep() -> HSeparator:
	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(PANEL_W - PAD * 2, 6)
	var style := StyleBoxFlat.new()
	style.bg_color = C_SEP
	style.content_margin_top = 2
	sep.add_theme_stylebox_override("separator", style)
	return sep

func _make_row_container() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(PANEL_W - PAD * 2, 14)
	hbox.add_theme_constant_override("separation", 4)
	return hbox

func _make_dim_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", C_TEXT_DIM)
	return lbl

func _make_stat_label() -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", C_TEXT)
	lbl.custom_minimum_size = Vector2(PANEL_W - PAD * 2, 16)
	return lbl

func _btn_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(3)
	s.content_margin_left = 8
	s.content_margin_right = 4
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s

func _on_close_pressed() -> void:
	hide_panel()
	closed.emit()
