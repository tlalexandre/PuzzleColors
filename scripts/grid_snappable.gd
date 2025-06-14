# grid_snappable.gd - Component to make any Node2D snap to grid
@tool
extends Node
class_name GridSnappable

@export var snap_to_grid: bool = true
@export var grid_size: int = 64

var parent_node: Node2D
var last_position: Vector2

func _ready():
	parent_node = get_parent() as Node2D
	if not parent_node:
		print("GridSnappable: Parent must be a Node2D")
		return
	
	# Snap to grid on start
	if snap_to_grid:
		snap_parent_to_grid()
		last_position = parent_node.position

func _process(_delta):
	# Only run in editor
	if not Engine.is_editor_hint():
		return
		
	if not parent_node or not snap_to_grid:
		return
	
	# Check if position changed (user moved the object)
	if parent_node.position != last_position:
		snap_parent_to_grid()
		last_position = parent_node.position

func snap_parent_to_grid():
	if not parent_node:
		return
		
	var snapped_pos = snap_position_to_grid(parent_node.position)
	parent_node.position = snapped_pos

func snap_position_to_grid(pos: Vector2) -> Vector2:
	return Vector2(
		round(pos.x / grid_size) * grid_size,
		round(pos.y / grid_size) * grid_size
	)

# Helper function to get grid coordinates
func get_grid_coordinates() -> Vector2i:
	if not parent_node:
		return Vector2i.ZERO
	return Vector2i(
		int(parent_node.position.x / grid_size),
		int(parent_node.position.y / grid_size)
	)

# Helper function to set grid coordinates
func set_grid_coordinates(grid_x: int, grid_y: int):
	if not parent_node:
		return
	parent_node.position = Vector2(grid_x * grid_size, grid_y * grid_size)
	last_position = parent_node.position
