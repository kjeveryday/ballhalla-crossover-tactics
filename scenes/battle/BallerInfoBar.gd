extends Node2D
class_name BallerInfoBar
# BallerInfoBar — left-aligned status bar replacing the dense _status_label.
# Drawn in HUD CanvasLayer at y=56. Shows baller name, [BALL] tag,
# stamina bar, hype bar, and action pips.

const BAR_W   := 72.0
const BAR_H   := 8.0
const PIP_R   := 4.5
const PIP_GAP := 3.0

const C_BG        := Color(0.07, 0.07, 0.10, 0.88)
const C_BDR       := Color(0.25, 0.30, 0.45, 0.70)
const C_TEXT      := Color(0.90, 0.90, 0.90, 1.00)
const C_DIM       := Color(0.55, 0.55, 0.60, 1.00)
const C_BALL_TAG  := Color(1.00, 0.55, 0.10, 1.00)
const C_BAR_BG    := Color(0.15, 0.15, 0.18, 1.00)
const C_STAM_HIGH := Color(0.20, 0.85, 0.30, 1.00)
const C_STAM_MID  := Color(0.95, 0.80, 0.10, 1.00)
const C_STAM_LOW  := Color(0.90, 0.20, 0.15, 1.00)
const C_HYPE      := Color(1.00, 0.80, 0.15, 1.00)
const C_PIP_ON    := Color(0.40, 0.70, 1.00, 1.00)
const C_PIP_OFF   := Color(0.25, 0.25, 0.30, 1.00)

# Cached state — set by refresh(), read by _draw()
var _name      : String  = "—"
var _has_ball  : bool    = false
var _stam_pct  : float   = 1.0
var _hype_pct  : float   = 0.0
var _actions   : int     = 3

func refresh(baller: Node) -> void:
	_name     = baller.stats.display_name
	_has_ball = baller.has_ball
	_stam_pct = float(baller.current_stamina) / float(baller.stats.max_stamina)
	_hype_pct = baller.current_hype / 100.0
	_actions  = BeatManager.actions_remaining
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var x    := 0.0
	var cy   := 13.0   # vertical center of bar area
	var h    := 26.0   # total bar height

	# Background
	draw_rect(Rect2(0, 0, 415, h), C_BG)
	draw_rect(Rect2(0, 0, 415, h), C_BDR, false, 1.0)

	x = 6.0

	# Name label
	var name_text: String = "► " + _name
	draw_string(font, Vector2(x, cy + 4), name_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_TEXT)
	x += 108.0

	# [BALL] tag
	if _has_ball:
		draw_string(font, Vector2(x, cy + 3), "[BALL]",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_BALL_TAG)
		x += 44.0
	else:
		x += 44.0  # reserve same space so pips stay anchored

	# STM label
	draw_string(font, Vector2(x, cy + 3), "STM",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_DIM)
	x += 28.0

	# Stamina bar background
	var stam_rect := Rect2(x, cy - BAR_H * 0.5, BAR_W, BAR_H)
	draw_rect(stam_rect, C_BAR_BG)
	var stam_fill_color: Color
	if _stam_pct > 0.60:
		stam_fill_color = C_STAM_HIGH
	elif _stam_pct > 0.30:
		stam_fill_color = C_STAM_MID
	else:
		stam_fill_color = C_STAM_LOW
	draw_rect(Rect2(x, cy - BAR_H * 0.5, BAR_W * _stam_pct, BAR_H), stam_fill_color)
	x += BAR_W + 8.0

	# HYP label
	draw_string(font, Vector2(x, cy + 3), "HYP",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_DIM)
	x += 28.0

	# Hype bar
	var hype_rect := Rect2(x, cy - BAR_H * 0.5, BAR_W, BAR_H)
	draw_rect(hype_rect, C_BAR_BG)
	draw_rect(Rect2(x, cy - BAR_H * 0.5, BAR_W * _hype_pct, BAR_H), C_HYPE)
	x += BAR_W + 8.0

	# ACT label
	draw_string(font, Vector2(x, cy + 3), "ACT",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_DIM)
	x += 28.0

	# Action pips
	for i in range(3):
		var color: Color = C_PIP_ON if i < _actions else C_PIP_OFF
		draw_circle(Vector2(x + PIP_R, cy), PIP_R, color)
		x += PIP_R * 2.0 + PIP_GAP
