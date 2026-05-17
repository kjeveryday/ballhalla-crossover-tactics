extends Control
class_name ScoreboardPanel
# ScoreboardPanel — top-center scoreboard showing score, quarter, beat, and possession.

const PANEL_W  := 400
const PANEL_H  := 52
const C_BG     := Color(0.06, 0.06, 0.10, 0.92)
const C_BDR    := Color(0.28, 0.38, 0.60, 0.85)
const C_ALLIED := Color(0.40, 0.80, 1.00, 1.00)
const C_ENEMY  := Color(1.00, 0.45, 0.45, 1.00)
const C_DIM    := Color(0.55, 0.55, 0.60, 1.00)
const C_WHITE  := Color(0.95, 0.95, 0.95, 1.00)

var _allied_score_label: Label
var _enemy_score_label : Label
var _center_label      : Label
var _possession_label  : Label

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	size               = Vector2(PANEL_W, PANEL_H)
	_build()

	QuarterManager.score_changed.connect(func(_a, _e): _refresh())
	QuarterManager.quarter_ended.connect(func(_q): _refresh())
	BeatManager.beat_started.connect(func(_n): _refresh())
	GameStateMachine.state_changed.connect(func(_o, _n): _refresh_possession())

	_refresh()

func refresh() -> void:
	_refresh()

func _build() -> void:
	# Background panel
	var bg := Panel.new()
	bg.size = Vector2(PANEL_W, PANEL_H)
	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = C_BDR
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)

	# Outer HBox: left | center | right
	var hbox := HBoxContainer.new()
	hbox.position = Vector2(8, 4)
	hbox.custom_minimum_size = Vector2(PANEL_W - 16, 24)
	hbox.add_theme_constant_override("separation", 4)
	add_child(hbox)

	# Left section: allied team name + score
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(110, 24)
	hbox.add_child(left_vbox)

	var allied_name := Label.new()
	allied_name.text = "REMIX"
	allied_name.add_theme_font_size_override("font_size", 10)
	allied_name.add_theme_color_override("font_color", C_ALLIED)
	left_vbox.add_child(allied_name)

	_allied_score_label = Label.new()
	_allied_score_label.add_theme_font_size_override("font_size", 18)
	_allied_score_label.add_theme_color_override("font_color", C_WHITE)
	left_vbox.add_child(_allied_score_label)

	# Center section: Q / Beat / Actions
	var center_vbox := VBoxContainer.new()
	center_vbox.custom_minimum_size = Vector2(140, 24)
	center_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(center_vbox)

	_center_label = Label.new()
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.add_theme_font_size_override("font_size", 12)
	_center_label.add_theme_color_override("font_color", C_WHITE)
	center_vbox.add_child(_center_label)

	_possession_label = Label.new()
	_possession_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_possession_label.add_theme_font_size_override("font_size", 10)
	_possession_label.add_theme_color_override("font_color", C_ALLIED)
	center_vbox.add_child(_possession_label)

	# Right section: score + enemy team name
	var right_vbox := VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(110, 24)
	right_vbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_child(right_vbox)

	_enemy_score_label = Label.new()
	_enemy_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_enemy_score_label.add_theme_font_size_override("font_size", 18)
	_enemy_score_label.add_theme_color_override("font_color", C_WHITE)
	right_vbox.add_child(_enemy_score_label)

	var enemy_name := Label.new()
	enemy_name.text = "STARS"
	enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_name.add_theme_font_size_override("font_size", 10)
	enemy_name.add_theme_color_override("font_color", C_ENEMY)
	right_vbox.add_child(enemy_name)

func _refresh() -> void:
	_allied_score_label.text = str(QuarterManager.allied_score)
	_enemy_score_label.text  = str(QuarterManager.enemy_score)
	_center_label.text = "Q%d   Beat %d/%d   Act %d" % [
		QuarterManager.current_quarter,
		BeatManager.current_beat,
		BeatManager.BEATS_PER_POSSESSION,
		BeatManager.actions_remaining,
	]
	_refresh_possession()

func _refresh_possession() -> void:
	var s: int = GameStateMachine.current_state
	var BS := GameStateMachine.BattleState
	var is_allied: bool = s in [
		BS.OFFENSE_START, BS.SELECTING_BALLER,
		BS.SELECTING_ACTION, BS.SELECTING_TARGET, BS.RESOLVING_ACTION,
	]
	if is_allied:
		_possession_label.text = "◀  ALLIED POSSESSION"
		_possession_label.add_theme_color_override("font_color", C_ALLIED)
	elif s == BS.DEFENSE_PHASE:
		_possession_label.text = "ENEMY POSSESSION  ▶"
		_possession_label.add_theme_color_override("font_color", C_ENEMY)
	else:
		_possession_label.text = ""
