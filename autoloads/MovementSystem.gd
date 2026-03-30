extends Node
# MovementSystem — Autoload
# Handles in-motion baller continuation (beat step ⑤).
# Called by BeatManager._resolve_in_motion_ballers() each beat.

# Advance baller one step toward their destination.
# Uses simple greedy pathfinding: move along the axis with larger delta.
func continue_movement(baller: Node) -> void:
	if not baller.is_in_motion:
		return
	var dest: Vector2i = baller.move_destination
	if dest == Vector2i(-1, -1):
		baller.is_in_motion = false
		return

	# Respect grab delay
	if baller.beats_to_destination > 0:
		baller.beats_to_destination -= 1
		print("[MOVE] %s grab-delayed — %d beat(s) remaining" % [
			baller.stats.display_name, baller.beats_to_destination])
		return

	var next: Vector2i = _pathfind_one_step(baller.grid_col, baller.grid_row, dest)
	if GridManager.get_cell(next.x, next.y) != null:
		baller.place_on_grid(next.x, next.y)
		print("[MOVE] %s step → (%d, %d)" % [baller.stats.display_name, next.x, next.y])

	# Arrived?
	if Vector2i(baller.grid_col, baller.grid_row) == dest:
		baller.is_in_motion = false
		baller.move_destination = Vector2i(-1, -1)
		print("[MOVE] %s arrived at destination (%d, %d)" % [
			baller.stats.display_name, dest.x, dest.y])

# Resolve all in-motion allied ballers. Called by BeatManager.
func resolve_all_in_motion() -> void:
	for b in AlliedTeam.get_active_ballers():
		if b.is_in_motion:
			continue_movement(b)

# Returns the next grid cell (col, row) one step toward dest using greedy axis choice.
func _pathfind_one_step(col: int, row: int, dest: Vector2i) -> Vector2i:
	var dc: int = dest.x - col
	var dr: int = dest.y - row
	if abs(dc) >= abs(dr):
		return Vector2i(col + sign(dc), row)
	else:
		return Vector2i(col, row + sign(dr))
