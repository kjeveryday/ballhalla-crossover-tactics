extends Control
# ConfirmDialog — small modal for "End beat with unused actions?" confirmation.
# Y / Enter = confirm, N / ESC = cancel.

signal confirmed()
signal cancelled()

const W := 260.0
const H := 90.0

var _label: Label

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	position = Vector2((816.0 - W) * 0.5, (716.0 - H) * 0.5)
	custom_minimum_size = Vector2(W, H)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.14, 0.97)
	style.border_color = Color(0.30, 0.35, 0.55, 0.80)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(W, H)
	panel.size = Vector2(W, H)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_label = Label.new()
	_label.position = Vector2(14.0, 13.0)
	_label.custom_minimum_size = Vector2(W - 28.0, 22.0)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.95))
	panel.add_child(_label)

	var sep := ColorRect.new()
	sep.color = Color(0.35, 0.35, 0.50, 0.50)
	sep.position = Vector2(12.0, 40.0)
	sep.size = Vector2(W - 24.0, 1.0)
	panel.add_child(sep)

	var yes_btn := _make_btn("Yes  [Y]")
	yes_btn.position = Vector2(42.0, 50.0)
	yes_btn.pressed.connect(_on_yes)
	panel.add_child(yes_btn)

	var no_btn := _make_btn("No  [N]")
	no_btn.position = Vector2(148.0, 50.0)
	no_btn.pressed.connect(_on_no)
	panel.add_child(no_btn)

func show_confirm(message: String) -> void:
	_label.text = message
	visible = true

func _on_yes() -> void:
	visible = false
	confirmed.emit()

func _on_no() -> void:
	visible = false
	cancelled.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_Y, KEY_ENTER, KEY_KP_ENTER:
				_on_yes()
				get_viewport().set_input_as_handled()
			KEY_N, KEY_ESCAPE:
				_on_no()
				get_viewport().set_input_as_handled()

func _make_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(70.0, 28.0)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(0.90, 0.92, 0.98))
	var s_norm := StyleBoxFlat.new()
	s_norm.bg_color = Color(0.15, 0.22, 0.38)
	s_norm.set_corner_radius_all(4)
	s_norm.border_width_top = 1
	s_norm.border_width_right = 1
	s_norm.border_width_bottom = 1
	s_norm.border_width_left = 1
	s_norm.border_color = Color(0.30, 0.40, 0.60, 0.60)
	btn.add_theme_stylebox_override("normal", s_norm)
	var s_hover: StyleBoxFlat = s_norm.duplicate()
	s_hover.bg_color = Color(0.22, 0.32, 0.52)
	btn.add_theme_stylebox_override("hover", s_hover)
	return btn
