extends Node2D
# FloatingTextSpawner — object pool for FloatingText nodes.
# Pool cap: 8 simultaneous nodes. When full, the oldest active node is recycled.
# All spawn methods take world_pos in court-space (parent is _court Node2D).

const POOL_SIZE: int = 8

var _pool: Array = []         # All FloatingText nodes (active or idle)
var _active: Array = []       # Currently animating nodes (oldest first)

func _ready() -> void:
	for i in range(POOL_SIZE):
		var ft: FloatingText = FloatingText.new()
		ft._pool_callback = _return_to_pool
		add_child(ft)
		_pool.append(ft)

# ── Public spawn methods ─────────────────────────────────────────────────────

func spawn_score(pos: Vector2, points: int) -> void:
	_spawn(pos, "+%d" % points, Color(1.0, 1.0, 0.4), 22)

func spawn_miss(pos: Vector2) -> void:
	_spawn(pos, "MISS", Color(1.0, 0.25, 0.25), 16)

func spawn_stamina(pos: Vector2, delta: int) -> void:
	var text: String = "%+d STM" % delta
	var color: Color = Color(0.4, 1.0, 0.5) if delta > 0 else Color(1.0, 0.4, 0.3)
	_spawn(pos, text, color, 13)

func spawn_hype(pos: Vector2, delta: int) -> void:
	var text: String = "%+d HYPE" % delta
	_spawn(pos, text, Color(1.0, 0.85, 0.2), 13)

func spawn_event(pos: Vector2, text: String) -> void:
	_spawn(pos, text, Color(1.0, 1.0, 1.0), 15)

# ── Internal ─────────────────────────────────────────────────────────────────

func _spawn(pos: Vector2, text: String, color: Color, font_size: int) -> void:
	var ft: FloatingText = _get_node()
	_active.append(ft)
	ft.play(pos, text, color, font_size)

func _get_node() -> FloatingText:
	# Find an idle node first
	for ft in _pool:
		if not _active.has(ft):
			return ft
	# Pool exhausted — recycle the oldest active node
	var oldest: FloatingText = _active.pop_front()
	return oldest

func _return_to_pool(ft: FloatingText) -> void:
	_active.erase(ft)
