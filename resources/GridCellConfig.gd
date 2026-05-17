class_name GridCellConfig
extends Resource
# Override passability or movement cost for a specific cell on a given court.
# Create a .tres file and call GridManager.apply_cell_config(config) at court load.

@export var col: int = 0
@export var row: int = 0
@export var passable: bool = true
@export var movement_cost: int = 1  # 1 = normal; higher = harder to enter (screen gravity field)
