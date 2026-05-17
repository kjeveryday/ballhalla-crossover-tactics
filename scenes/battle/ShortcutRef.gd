extends Control
# ShortcutRef — full-screen shortcut reference overlay.
# Shown on ? key, dismissed by any keypress.

const SCREEN_W := 816.0
const SCREEN_H := 716.0
const PANEL_W  := 460.0
const PANEL_H  := 322.0
const PANEL_X  := (SCREEN_W - PANEL_W) * 0.5
const PANEL_Y  := (SCREEN_H - PANEL_H) * 0.5

# Two-column layout: [left_key, left_action, right_key, right_action]
const SHORTCUTS := [
	["Click", "Select baller",   "Tab",    "Next available baller"],
	["M",     "Move",            "C",      "Cut (toward basket)"],
	["P",     "Pass",            "S",      "Shoot"],
	["X",     "Screen",          "T",      "Talk (submenu)"],
	["L",     "Leadership",      "I",      "ISO Talk"],
	["1–4",   "Play calls",      "Space",  "End Turn"],
	["Enter", "End Beat",        "Ctrl+Z", "Undo last move"],
	["D",     "Toggle overlay",  "`",      "Toggle log panel"],
	["ESC",   "Cancel",          "?",      "This screen"],
]

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visibility_changed.connect(func(): queue_redraw())
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		visible = false
		get_viewport().set_input_as_handled()

func _draw() -> void:
	var font := ThemeDB.fallback_font

	# Full-screen dim
	draw_rect(Rect2(0.0, 0.0, SCREEN_W, SCREEN_H), Color(0.0, 0.0, 0.0, 0.75))

	# Panel background
	draw_rect(Rect2(PANEL_X, PANEL_Y, PANEL_W, PANEL_H), Color(0.09, 0.09, 0.14, 0.97))
	draw_rect(Rect2(PANEL_X, PANEL_Y, PANEL_W, PANEL_H),
		Color(0.30, 0.35, 0.55, 0.80), false, 1.5)

	var y := PANEL_Y + 22.0

	# Title
	draw_string(font, Vector2(PANEL_X, y), "KEYBOARD SHORTCUTS",
		HORIZONTAL_ALIGNMENT_CENTER, PANEL_W, 16, Color(0.80, 0.85, 1.00))
	y += 24.0

	# Title separator
	draw_line(Vector2(PANEL_X + 16.0, y), Vector2(PANEL_X + PANEL_W - 16.0, y),
		Color(0.30, 0.35, 0.50, 0.60), 1.0)
	y += 12.0

	# Column positions
	var c1k := PANEL_X + 20.0   # left key
	var c1a := PANEL_X + 72.0   # left action
	var c2k := PANEL_X + 248.0  # right key
	var c2a := PANEL_X + 316.0  # right action

	for row in SHORTCUTS:
		draw_string(font, Vector2(c1k, y), row[0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.82, 0.30))
		draw_string(font, Vector2(c1a, y), row[1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.82, 0.82, 0.82))
		draw_string(font, Vector2(c2k, y), row[2],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.82, 0.30))
		draw_string(font, Vector2(c2a, y), row[3],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.82, 0.82, 0.82))
		y += 26.0

	y += 4.0
	draw_string(font, Vector2(PANEL_X, y), "Press any key to dismiss",
		HORIZONTAL_ALIGNMENT_CENTER, PANEL_W, 11, Color(0.50, 0.50, 0.60))
