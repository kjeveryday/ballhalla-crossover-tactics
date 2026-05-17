extends Node
# MovementSystem — Autoload
# Handles in-motion baller continuation (beat step ⑤).
# Called by BeatManager._resolve_in_motion_ballers() each beat.
# Grid state (grid_col/grid_row) updates instantly. baller_moved fires so
# BattleDemo can tween baller.position as a visual-only follow-up.

signal baller_moved(baller: Node, world_pos: Vector2)

var _paths: Dictionary = {}  # baller -> Array of GridCell remaining steps

# Store the pre-computed BFS path for a baller. Call before continue_movement.
# path is the full route from origin to destination (origin cell first).
func set_path(baller: Node, path: Array) -> void:
	if path.size() > 1:
		_paths[baller] = path.slice(1)  # drop origin; remainder are steps to take
	else:
		_paths.erase(baller)

# Advance baller one step toward their destination.
# Uses BFS pre-computed path if set_path was called; falls back to greedy axis-choice.
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

	var next: Vector2i
	if _paths.has(baller) and not (_paths[baller] as Array).is_empty():
		var step: GridManager.GridCell = (_paths[baller] as Array).pop_front()
		next = Vector2i(step.col, step.row)
	else:
		next = _pathfind_one_step(baller.grid_col, baller.grid_row, dest)

	if GridManager.get_cell(next.x, next.y) != null:
		# Update grid state instantly; BattleDemo tweens the visual position
		var old_cell := GridManager.get_cell(baller.grid_col, baller.grid_row)
		if old_cell != null and old_cell.occupant == baller:
			old_cell.occupant = null
		baller.grid_col = next.x
		baller.grid_row = next.y
		var new_cell := GridManager.get_cell(next.x, next.y)
		if new_cell != null:
			new_cell.occupant = baller
		var world_pos: Vector2 = GridManager.grid_to_world(next.x, next.y)
		baller_moved.emit(baller, world_pos)
		print("[MOVE] %s step → (%d, %d)" % [baller.stats.display_name, next.x, next.y])

	# Arrived?
	if Vector2i(baller.grid_col, baller.grid_row) == dest:
		baller.is_in_motion = false
		baller.move_destination = Vector2i(-1, -1)
		_paths.erase(baller)
		print("[MOVE] %s arrived at destination (%d, %d)" % [
			baller.stats.display_name, dest.x, dest.y])

# Resolve all in-motion allied ballers. Called by BeatManager.
func resolve_all_in_motion() -> void:
	for b in AlliedTeam.get_active_ballers():
		if b.is_in_motion:
			continue_movement(b)

# Greedy fallback: one step toward dest along the dominant axis.
func _pathfind_one_step(col: int, row: int, dest: Vector2i) -> Vector2i:
	var dc: int = dest.x - col
	var dr: int = dest.y - row
	if abs(dc) >= abs(dr):
		return Vector2i(col + sign(dc), row)
	else:
		return Vector2i(col, row + sign(dr))
