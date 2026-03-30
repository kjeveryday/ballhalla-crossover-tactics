extends Node2D
# TestSelection — Step 5: Allied Selection + UI Shell

const ALLIED_STATS: Array = [
	preload("res://resources/stats/allied/pg_remix.tres"),
	preload("res://resources/stats/allied/sg_remix.tres"),
	preload("res://resources/stats/allied/sf_remix.tres"),
	preload("res://resources/stats/allied/pf_remix.tres"),
	preload("res://resources/stats/allied/c_remix.tres"),
]

const ENEMY_STATS: Array = [
	preload("res://resources/stats/enemy/hollywood_pg.tres"),
	preload("res://resources/stats/enemy/hollywood_sg.tres"),
	preload("res://resources/stats/enemy/hollywood_sf.tres"),
	preload("res://resources/stats/enemy/hollywood_pf.tres"),
	preload("res://resources/stats/enemy/hollywood_c.tres"),
]

const ALLIED_POSITIONS: Array = [[4,10],[2,9],[6,9],[1,8],[7,8]]
const ENEMY_POSITIONS: Array  = [[4,5],[2,5],[4,3],[2,2],[4,1]]

const AlliedBallerScene: PackedScene = preload("res://entities/baller/AlliedBaller.tscn")
const EnemyBallerScene: PackedScene  = preload("res://entities/baller/EnemyBaller.tscn")

var allied_ballers: Array = []
var enemy_ballers: Array = []
var selected_baller = null
var highlight_cells: Array = []

var _action_panel: Panel
var _name_label: Label
var _stamina_bar: ProgressBar
var _hype_bar: ProgressBar

func _ready() -> void:
	_spawn_ballers()
	_build_ui()
	GameStateMachine.state_changed.connect(_on_state_changed)
	GameStateMachine.transition_to(GameStateMachine.BattleState.OFFENSE_START)
	GameStateMachine.transition_to(GameStateMachine.BattleState.SELECTING_BALLER)
	print("=== TestSelection ready — click allied baller to select, Escape to deselect ===")

func _spawn_ballers() -> void:
	for i in range(5):
		var b: Node = AlliedBallerScene.instantiate()
		b.set("stats", ALLIED_STATS[i])
		b.set("grid_col", ALLIED_POSITIONS[i][0])
		b.set("grid_row", ALLIED_POSITIONS[i][1])
		add_child(b)
		allied_ballers.append(b)

	for i in range(5):
		var b: Node = EnemyBallerScene.instantiate()
		b.set("stats", ENEMY_STATS[i])
		b.set("grid_col", ENEMY_POSITIONS[i][0])
		b.set("grid_row", ENEMY_POSITIONS[i][1])
		add_child(b)
		enemy_ballers.append(b)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	# --- Baller info strip (bottom-left) ---
	var info_bg := Panel.new()
	info_bg.anchor_left = 0.0
	info_bg.anchor_top = 1.0
	info_bg.anchor_right = 0.0
	info_bg.anchor_bottom = 1.0
	info_bg.offset_left = 8
	info_bg.offset_top = -78
	info_bg.offset_right = 420
	info_bg.offset_bottom = -8
	canvas.add_child(info_bg)

	var info_vbox := VBoxContainer.new()
	info_vbox.anchor_right = 1.0
	info_vbox.anchor_bottom = 1.0
	info_vbox.offset_left = 6
	info_vbox.offset_top = 4
	info_vbox.offset_right = -6
	info_vbox.offset_bottom = -4
	info_bg.add_child(info_vbox)

	_name_label = Label.new()
	_name_label.text = "No baller selected"
	info_vbox.add_child(_name_label)

	var stamina_row := HBoxContainer.new()
	info_vbox.add_child(stamina_row)
	var st_lbl := Label.new()
	st_lbl.text = "Stamina"
	st_lbl.custom_minimum_size = Vector2(64, 0)
	stamina_row.add_child(st_lbl)
	_stamina_bar = ProgressBar.new()
	_stamina_bar.min_value = 0.0
	_stamina_bar.max_value = 100.0
	_stamina_bar.value = 0.0
	_stamina_bar.custom_minimum_size = Vector2(200, 16)
	stamina_row.add_child(_stamina_bar)

	var hype_row := HBoxContainer.new()
	info_vbox.add_child(hype_row)
	var hp_lbl := Label.new()
	hp_lbl.text = "Hype"
	hp_lbl.custom_minimum_size = Vector2(64, 0)
	hype_row.add_child(hp_lbl)
	_hype_bar = ProgressBar.new()
	_hype_bar.min_value = 0.0
	_hype_bar.max_value = 1.0
	_hype_bar.value = 0.0
	_hype_bar.custom_minimum_size = Vector2(200, 16)
	hype_row.add_child(_hype_bar)

	# --- Action panel (bottom-right, visible only in SELECTING_ACTION) ---
	_action_panel = Panel.new()
	_action_panel.anchor_left = 1.0
	_action_panel.anchor_top = 1.0
	_action_panel.anchor_right = 1.0
	_action_panel.anchor_bottom = 1.0
	_action_panel.offset_left = -436
	_action_panel.offset_top = -78
	_action_panel.offset_right = -8
	_action_panel.offset_bottom = -8
	_action_panel.visible = false
	canvas.add_child(_action_panel)

	var action_hbox := HBoxContainer.new()
	action_hbox.anchor_right = 1.0
	action_hbox.anchor_bottom = 1.0
	action_hbox.offset_left = 6
	action_hbox.offset_top = 6
	action_hbox.offset_right = -6
	action_hbox.offset_bottom = -6
	_action_panel.add_child(action_hbox)

	for action_name: String in ["Move", "Pass", "Shoot", "End Turn", "Screen", "Talk"]:
		var btn := Button.new()
		btn.text = action_name
		var n: String = action_name
		btn.pressed.connect(func(): print("[ACTION] %s" % n))
		action_hbox.add_child(btn)

	# --- Shot clock stub (top-right) ---
	var clock_lbl := Label.new()
	clock_lbl.anchor_left = 1.0
	clock_lbl.anchor_top = 0.0
	clock_lbl.anchor_right = 1.0
	clock_lbl.anchor_bottom = 0.0
	clock_lbl.offset_left = -160
	clock_lbl.offset_top = 8
	clock_lbl.offset_right = -8
	clock_lbl.offset_bottom = 30
	clock_lbl.text = "SHOT CLOCK: --"
	canvas.add_child(clock_lbl)

	# --- Beat group HUD stub (top-left) ---
	var beat_lbl := Label.new()
	beat_lbl.anchor_left = 0.0
	beat_lbl.anchor_top = 0.0
	beat_lbl.anchor_right = 0.0
	beat_lbl.anchor_bottom = 0.0
	beat_lbl.offset_left = 8
	beat_lbl.offset_top = 8
	beat_lbl.offset_right = 220
	beat_lbl.offset_bottom = 30
	beat_lbl.text = "BEAT: --  GROUP: --"
	canvas.add_child(beat_lbl)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(get_global_mouse_position())
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_clear_selection()

func _handle_click(world_pos: Vector2) -> void:
	var gp: Vector2i = GridManager.world_to_grid(world_pos)
	if gp == Vector2i(-1, -1):
		return
	var cs: int = GameStateMachine.current_state
	var sb: int = GameStateMachine.BattleState.SELECTING_BALLER
	var sa: int = GameStateMachine.BattleState.SELECTING_ACTION
	if cs != sb and cs != sa:
		return
	var baller = _baller_at(gp.x, gp.y)
	if baller != null and baller.get("team") == 0:
		_select_baller(baller)
	else:
		var what: String = "enemy" if (baller != null) else "empty"
		print("[SELECT] Clicked %s cell (%d,%d) — no action" % [what, gp.x, gp.y])

func _baller_at(col: int, row: int):
	for b in allied_ballers:
		if b.get("grid_col") == col and b.get("grid_row") == row:
			return b
	for b in enemy_ballers:
		if b.get("grid_col") == col and b.get("grid_row") == row:
			return b
	return null

func _select_baller(baller) -> void:
	selected_baller = baller
	var s = baller.get("stats")
	var spd: int = 3
	if s != null:
		spd = s.speed
	highlight_cells = GridManager.get_cells_in_range(
		baller.get("grid_col"), baller.get("grid_row"), spd)
	queue_redraw()
	_update_info_strip()
	var dname: String = s.display_name if s != null else "?"
	print("[SELECT] Allied: %s at (%d,%d) — speed %d, %d cells highlighted" % [
		dname, baller.get("grid_col"), baller.get("grid_row"),
		spd, highlight_cells.size()])
	if GameStateMachine.current_state != GameStateMachine.BattleState.SELECTING_ACTION:
		GameStateMachine.transition_to(GameStateMachine.BattleState.SELECTING_ACTION)

func _clear_selection() -> void:
	selected_baller = null
	highlight_cells = []
	queue_redraw()
	_update_info_strip()
	print("[SELECT] Cleared")
	if GameStateMachine.current_state != GameStateMachine.BattleState.SELECTING_BALLER:
		GameStateMachine.transition_to(GameStateMachine.BattleState.SELECTING_BALLER)

func _update_info_strip() -> void:
	if selected_baller == null:
		_name_label.text = "No baller selected"
		_stamina_bar.max_value = 100.0
		_stamina_bar.value = 0.0
		_hype_bar.value = 0.0
		return
	var s = selected_baller.get("stats")
	_name_label.text = s.display_name if s != null else "Unknown"
	var max_st: float = float(s.max_stamina) if s != null else 100.0
	_stamina_bar.max_value = max_st
	_stamina_bar.value = float(selected_baller.get("current_stamina"))
	_hype_bar.value = float(selected_baller.get("current_hype"))

func _on_state_changed(_old_state: int, new_state: int) -> void:
	_action_panel.visible = (new_state == GameStateMachine.BattleState.SELECTING_ACTION)

func _draw() -> void:
	for cell in highlight_cells:
		var x: float = float((GridManager.GRID_ROWS - 1 - cell.row) * GridManager.CELL_SIZE)
		var y: float = float(cell.col * GridManager.CELL_SIZE)
		draw_rect(
			Rect2(x, y, GridManager.CELL_SIZE, GridManager.CELL_SIZE),
			Color(1.0, 1.0, 0.0, 0.35))
