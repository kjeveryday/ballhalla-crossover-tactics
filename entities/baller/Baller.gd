extends CharacterBody2D
class_name Baller
# Baller — base class shared by allied and enemy ballers.
# Stats + grid position + team affiliation only. No ability code.

@export var stats: Resource   # BallerStats instance

var team: int = 0              # 0 = allied, 1 = enemy
var grid_col: int = 0
var grid_row: int = 0
var has_ball: bool = false

var current_stamina: int = 0
var current_hype: float = 0.0
var gravity: int = 0

var is_exhausted: bool = false
var is_active: bool = true
var acted_this_beat: bool = false
var consecutive_actions: int = 0
var is_in_motion: bool = false
var move_destination: Vector2i = Vector2i(-1, -1)
var beats_to_destination: int = 0

var guard_assignment = null   # Baller — set by EnemyAI (Step 11)

func _ready() -> void:
	if stats != null:
		current_stamina = stats.max_stamina
		gravity = stats.gravity_base
	place_on_grid(grid_col, grid_row)

func place_on_grid(col: int, row: int) -> void:
	grid_col = col
	grid_row = row
	position = GridManager.grid_to_world(col, row)

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
