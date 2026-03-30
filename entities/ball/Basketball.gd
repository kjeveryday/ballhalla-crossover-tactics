class_name Basketball extends Node2D
# Basketball — first-class game object.
# Ball possession is a data flag, not proximity.
# Add to scene and place at the point guard's starting cell.

enum BallState {
	HELD,    # Held by a specific baller
	LOOSE,   # On the ground after turnover/missed rebound
	IN_AIR,  # Shot or pass in flight
	DEAD,    # Phase ended, ball inactive
}

var state: BallState = BallState.DEAD
var holder = null           # Baller node or null
var last_holder = null      # Used for turnover/steal attribution
var grid_position: Vector2i = Vector2i(-1, -1)  # Cell when LOOSE

signal ball_state_changed(new_state: BallState)

func give_to(baller) -> void:
	holder = baller
	state = BallState.HELD
	baller.has_ball = true
	ball_state_changed.emit(state)

func release() -> void:
	if holder != null:
		holder.has_ball = false
	last_holder = holder
	holder = null

func set_in_air() -> void:
	release()
	state = BallState.IN_AIR
	ball_state_changed.emit(state)

func set_loose(at_col: int, at_row: int) -> void:
	release()
	state = BallState.LOOSE
	grid_position = Vector2i(at_col, at_row)
	ball_state_changed.emit(state)

func set_dead() -> void:
	release()
	state = BallState.DEAD
	ball_state_changed.emit(state)
