extends Node2D
# TargetOverlay — drawn as a sibling of ballers inside the Court Node2D (court-space coords).
# Highlights valid cells (move targets) or baller tokens (pass / leadership targets).
# Uses _unhandled_input so ActionMenu button presses are consumed first.

signal cell_clicked(col: int, row: int)
signal baller_clicked(baller: Node)
signal cancelled()

enum Mode { NONE, CELLS, BALLERS }

var _mode: Mode = Mode.NONE
var _highlight_cells: Array = []   # Array of Vector2i (col, row)
var _highlight_ballers: Array = [] # Array of Baller nodes

const C_MOVE_FILL  := Color(0.15, 0.55, 1.00, 0.28)
const C_MOVE_EDGE  := Color(0.30, 0.70, 1.00, 0.85)
const C_ALLY_RING  := Color(0.10, 0.90, 0.40, 0.90)
const C_ALLY_FILL  := Color(0.10, 0.90, 0.40, 0.18)

# ── Public API ────────────────────────────────────────────────────────────────

func show_move_range(baller: Node) -> void:
	_mode = Mode.CELLS
	_highlight_cells.clear()
	_highlight_ballers.clear()

	var cells := GridManager.get_cells_in_range(baller.grid_col, baller.grid_row, 3)
	for cell in cells:
		# Skip occupied cells (any baller)
		if cell.occupant != null and cell.occupant != baller:
			continue
		_highlight_cells.append(Vector2i(cell.col, cell.row))

	set_process_unhandled_input(true)
	queue_redraw()

func show_ally_targets(allies: Array, exclude: Node) -> void:
	_mode = Mode.BALLERS
	_highlight_cells.clear()
	_highlight_ballers.clear()

	for b in allies:
		if b != exclude and not b.is_exhausted:
			_highlight_ballers.append(b)

	set_process_unhandled_input(true)
	queue_redraw()

func clear() -> void:
	_mode = Mode.NONE
	_highlight_cells.clear()
	_highlight_ballers.clear()
	set_process_unhandled_input(false)
	queue_redraw()

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	var cs: float = GridManager.CELL_SIZE

	if _mode == Mode.CELLS:
		for cell_pos in _highlight_cells:
			var world := GridManager.grid_to_world(cell_pos.x, cell_pos.y)
			var rect := Rect2(world.x - cs * 0.5, world.y - cs * 0.5, cs, cs)
			draw_rect(rect, C_MOVE_FILL)
			draw_rect(rect, C_MOVE_EDGE, false, 2.0)

	elif _mode == Mode.BALLERS:
		for b in _highlight_ballers:
			draw_circle(b.position, cs * 0.44, C_ALLY_FILL)
			# Ring — approximate with arc
			draw_arc(b.position, cs * 0.44, 0.0, TAU, 32, C_ALLY_RING, 2.5)

# ── Input ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_process_unhandled_input(false)

func _unhandled_input(event: InputEvent) -> void:
	if _mode == Mode.NONE:
		return

	# ESC or RMB cancels
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		emit_signal("cancelled")
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		get_viewport().set_input_as_handled()
		emit_signal("cancelled")
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Mouse pos in court-space (this node is a child of Court at (0,0))
		var local_pos: Vector2 = get_local_mouse_position()

		if _mode == Mode.BALLERS:
			var cs: float = GridManager.CELL_SIZE
			for b in _highlight_ballers:
				if local_pos.distance_to(b.position) <= cs * 0.44:
					get_viewport().set_input_as_handled()
					emit_signal("baller_clicked", b)
					return
			# Click outside any target → cancel
			get_viewport().set_input_as_handled()
			emit_signal("cancelled")

		elif _mode == Mode.CELLS:
			var grid_pos: Vector2i = GridManager.world_to_grid(local_pos)
			if grid_pos != Vector2i(-1, -1) and _highlight_cells.has(grid_pos):
				get_viewport().set_input_as_handled()
				emit_signal("cell_clicked", grid_pos.x, grid_pos.y)
				return
			# Click outside valid cells → cancel
			get_viewport().set_input_as_handled()
			emit_signal("cancelled")
