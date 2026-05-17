class_name TurnSnapshot
# TurnSnapshot — lightweight typed container for undo state.
# Captured before each reversible action (move, cut). Consumed by undo on Ctrl+Z (Step 22B).
# Not a Resource — does not need serialization; lives only in memory for one beat.

var actor: Node = null
var start_col: int = 0
var start_row: int = 0
var start_position: Vector2 = Vector2.ZERO  # Visual position for instant snap-back
var start_stamina: int = 0
var actions_at_start: int = 0
var has_moved: bool = false
var has_acted: bool = false

func capture(baller: Node) -> void:
	actor = baller
	start_col = baller.grid_col
	start_row = baller.grid_row
	start_position = baller.position
	start_stamina = baller.current_stamina
	actions_at_start = BeatManager.actions_remaining
	has_moved = baller.is_in_motion
	has_acted = baller.acted_this_beat

func restore() -> void:
	if actor == null:
		return
	# Clear old cell occupancy before moving — direct grid_col/row assignment bypasses GridManager
	var old_cell: GridManager.GridCell = GridManager.get_cell(actor.grid_col, actor.grid_row)
	if old_cell != null and old_cell.occupant == actor:
		old_cell.occupant = null
	actor.place_on_grid(start_col, start_row)
	actor.position = start_position  # Snap visual back exactly; overrides grid_to_world result
	actor.current_stamina = start_stamina
	actor.is_in_motion = false
	actor.acted_this_beat = has_acted
	actor.consecutive_actions = max(0, actor.consecutive_actions - 1)
	BeatManager.actions_remaining = actions_at_start
