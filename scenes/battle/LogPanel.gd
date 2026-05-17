extends Control
# LogPanel — scrollable full match history, toggled with ` (backtick).
# Positioned in the unused space to the right of the court.

const W := 210.0
const H := 620.0

const LOG_COLORS := {
	"score":    "[color=#88ff88]",
	"miss":     "[color=#ff6666]",
	"play":     "[color=#ffdd44]",
	"quarter":  "[color=#ffffff]",
	"stamina":  "[color=#ffaa44]",
	"turnover": "[color=#ff4444]",
	"default":  "[color=#bbbbbb]",
}

var _scroll: ScrollContainer
var _rich_text: RichTextLabel

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(W, H)
	visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.10, 0.95)
	style.border_color = Color(0.25, 0.30, 0.45, 0.70)
	style.set_border_width_all(1)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(W, H)
	panel.size = Vector2(W, H)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	# Header label
	var header := Label.new()
	header.text = "MATCH LOG"
	header.position = Vector2(8.0, 5.0)
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.55, 0.60, 0.80))
	panel.add_child(header)

	# Header separator
	var sep := ColorRect.new()
	sep.color = Color(0.25, 0.30, 0.45, 0.60)
	sep.position = Vector2(0.0, 22.0)
	sep.size = Vector2(W, 1.0)
	panel.add_child(sep)

	# Scroll container fills the rest of the panel
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0.0, 24.0)
	_scroll.custom_minimum_size = Vector2(W, H - 24.0)
	_scroll.size = Vector2(W, H - 24.0)
	panel.add_child(_scroll)

	# RichTextLabel inside scroll
	_rich_text = RichTextLabel.new()
	_rich_text.bbcode_enabled = true
	_rich_text.fit_content = true
	_rich_text.scroll_active = false
	_rich_text.custom_minimum_size = Vector2(W - 12.0, 0.0)
	_rich_text.add_theme_font_size_override("font_size", 11)
	_scroll.add_child(_rich_text)

func append(msg: String, category: String = "default") -> void:
	var color_tag: String = LOG_COLORS.get(category, LOG_COLORS["default"])
	_rich_text.append_text(color_tag + msg + "[/color]\n")
	# Auto-scroll to bottom after layout settles
	await get_tree().process_frame
	_scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value
