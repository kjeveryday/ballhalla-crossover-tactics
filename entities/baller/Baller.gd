extends CharacterBody2D
class_name Baller
# Baller — base class shared by allied and enemy ballers.
# Stats + grid position + team affiliation only. No ability code.

@export var stats: Resource   # BallerStats instance

var team: int = 0              # 0 = allied, 1 = enemy
var grid_col: int = 0
var grid_row: int = 0
var has_ball: bool = false:
	set(value):
		has_ball = value
		if is_inside_tree():
			set_process(value)  # Enable _process for ball carrier glow pulse; disable otherwise
			queue_redraw()

var current_stamina: int = 0
var current_hype: int = 0
var gravity: int = 0

var is_exhausted: bool = false
var is_active: bool = true:
	set(value):
		is_active = value
		if not value:
			var cell := GridManager.get_cell(grid_col, grid_row)
			if cell != null and cell.occupant == self:
				cell.occupant = null
var acted_this_beat: bool = false
var consecutive_actions: int = 0
var is_in_motion: bool = false
var move_destination: Vector2i = Vector2i(-1, -1)
var beats_to_destination: int = 0

var guard_assignment = null       # Baller — set by EnemyAI (Step 11)
var screen_recovery_timer: int = 0  # Beats until re-assignment after screen

func _ready() -> void:
	set_process(false)  # Only active when has_ball (drives glow pulse)
	if stats != null:
		current_stamina = stats.max_stamina
		gravity = stats.gravity_base
	place_on_grid(grid_col, grid_row)

func place_on_grid(col: int, row: int) -> void:
	var old_cell := GridManager.get_cell(grid_col, grid_row)
	if old_cell != null and old_cell.occupant == self:
		old_cell.occupant = null
	grid_col = col
	grid_row = row
	position = GridManager.grid_to_world(col, row)
	var new_cell := GridManager.get_cell(col, row)
	if new_cell != null:
		new_cell.occupant = self
	elif OS.is_debug_build():
		push_warning("[Baller] place_on_grid(%d,%d): cell not found — GridManager may not be ready" % [col, row])

func can_act() -> bool:
	return is_active and not is_exhausted

func drain_stamina(amount: int) -> void:
	current_stamina = max(0, current_stamina - amount)
	if current_stamina == 0:
		is_exhausted = true
		print("[STAM] %s is exhausted!" % stats.display_name)

func heal_stamina(amount: int) -> void:
	if is_exhausted:
		return
	current_stamina = min(stats.max_stamina, current_stamina + amount)
