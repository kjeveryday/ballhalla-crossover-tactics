extends Node2D
class_name FloatingText
# FloatingText — animated text label that rises and fades.
# Designed for pooling: call reset() to return to pool, not queue_free().
# FloatingTextSpawner manages the pool (cap 8); oldest node is recycled when full.

var _label: Label
var _tween: Tween = null
var _pool_callback: Callable = Callable()  # Set by spawner — called when animation ends

func _ready() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	visible = false

# Called by FloatingTextSpawner.spawn() to configure and run the animation.
func play(world_pos: Vector2, text: String, color: Color, font_size: int = 16) -> void:
	if _tween and _tween.is_running():
		# Disconnect before kill — CONNECT_ONE_SHOT lives on the tween object, not the
		# signal name, so kill() alone does not remove the connection. Without this,
		# recycling a node mid-animation would leave a dangling connection and cause
		# _pool_callback to fire twice on the new tween's finish.
		if _tween.finished.is_connected(_on_tween_done):
			_tween.finished.disconnect(_on_tween_done)
		_tween.kill()

	position = world_pos
	modulate.a = 1.0
	visible = true

	_label.text = text
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", color)
	_label.position = Vector2(-40.0, 0.0)  # Center-align offset
	_label.custom_minimum_size = Vector2(80.0, 0.0)

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:y", world_pos.y - 40.0, 0.7).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	_tween.finished.connect(_on_tween_done, CONNECT_ONE_SHOT)

func _on_tween_done() -> void:
	visible = false
	if _pool_callback.is_valid():
		_pool_callback.call(self)
