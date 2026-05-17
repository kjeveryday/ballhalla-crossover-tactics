extends Control
class_name ActivePlayBanner
# ActivePlayBanner — pill-shaped banner below the scoreboard.
# Visible only when a play is active. Flashes green on trigger, red on expire.

const BANNER_W := 300
const BANNER_H := 28
const C_BG     := Color(0.14, 0.12, 0.04, 0.92)
const C_BDR    := Color(1.00, 0.85, 0.20, 0.90)
const C_TEXT   := Color(1.00, 0.92, 0.30, 1.00)

var _label: Label
var _play_beat_start: int = 0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(BANNER_W, BANNER_H)
	size               = Vector2(BANNER_W, BANNER_H)
	visible = false
	_build()

	PlayManager.play_called.connect(_on_play_called)
	PlayManager.play_triggered.connect(_on_play_triggered)
	PlayManager.play_expired.connect(_on_play_expired)
	BeatManager.beat_ended.connect(_on_beat_ended)

func refresh() -> void:
	if PlayManager.active_play != null:
		_refresh_text()
	else:
		visible = false

func _build() -> void:
	var bg := Panel.new()
	bg.size = Vector2(BANNER_W, BANNER_H)
	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = C_BDR
	style.set_border_width_all(1)
	style.corner_radius_top_left    = 14
	style.corner_radius_top_right   = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right= 14
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)

	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", C_TEXT)
	add_child(_label)

func _on_play_called(_name: String) -> void:
	_play_beat_start = BeatManager.current_beat
	visible = true
	_refresh_text()

func _on_beat_ended(_n: int) -> void:
	if visible and PlayManager.active_play != null:
		_refresh_text()

func _refresh_text() -> void:
	if PlayManager.active_play == null:
		return
	var elapsed: int = BeatManager.current_beat - _play_beat_start
	_label.text = "▶  %s  —  Beat %d active" % [
		PlayManager.active_play.play_name.to_upper(), elapsed + 1]

func _on_play_triggered(play_name: String) -> void:
	_label.text = "✔  %s  TRIGGERED!" % play_name.to_upper()
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.3, 1.0, 0.3, 1.0), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.32)
	tween.finished.connect(func(): visible = false, CONNECT_ONE_SHOT)

func _on_play_expired(play_name: String) -> void:
	_label.text = "✘  %s  expired" % play_name.to_upper()
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.22)
	tween.finished.connect(func(): visible = false, CONNECT_ONE_SHOT)
