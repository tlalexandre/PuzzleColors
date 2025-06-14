# GridSystem.gd - Singleton for managing 64-pixel grid
extends Node

# Grid constants
const GRID_SIZE: int = 64
const GAME_WIDTH: int = 1152  # 18 grid units
const GAME_HEIGHT: int = 640  # 10 grid units (adjusted from 648 for perfect grid)


func _ready():
	# DON'T auto-load the first level anymore
	print("Grid System initialized - waiting for game to start")

# Grid helper functions
func snap_to_grid(position: Vector2) -> Vector2:
	"""Snap any position to the nearest grid point"""
	return Vector2(
		round(position.x / GRID_SIZE) * GRID_SIZE,
		round(position.y / GRID_SIZE) * GRID_SIZE
	)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	"""Convert grid coordinates to world position (center of grid cell)"""
	return Vector2(
		grid_pos.x * GRID_SIZE + GRID_SIZE / 2,
		grid_pos.y * GRID_SIZE + GRID_SIZE / 2
	)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	"""Convert world position to grid coordinates"""
	return Vector2i(
		int(world_pos.x / GRID_SIZE),
		int(world_pos.y / GRID_SIZE)
	)

func is_valid_grid_position(grid_pos: Vector2i) -> bool:
	"""Check if a grid position is within game bounds"""
	return grid_pos.x >= 0 and grid_pos.x < (GAME_WIDTH / GRID_SIZE) and \
		   grid_pos.y >= 0 and grid_pos.y < (GAME_HEIGHT / GRID_SIZE)

# Visual debug helpers
func draw_grid(canvas: CanvasItem, color: Color = Color.WHITE, alpha: float = 0.1):
	"""Draw grid lines for debugging"""
	var grid_color = Color(color.r, color.g, color.b, alpha)
	
	# Vertical lines
	for x in range(0, GAME_WIDTH + 1, GRID_SIZE):
		canvas.draw_line(
			Vector2(x, 0),
			Vector2(x, GAME_HEIGHT),
			grid_color,
			1.0
		)
	
	# Horizontal lines
	for y in range(0, GAME_HEIGHT + 1, GRID_SIZE):
		canvas.draw_line(
			Vector2(0, y),
			Vector2(GAME_WIDTH, y),
			grid_color,
			1.0
		)

# Grid positioning helpers for common use cases
func get_center_of_cell(grid_x: int, grid_y: int) -> Vector2:
	"""Get the center position of a specific grid cell"""
	return grid_to_world(Vector2i(grid_x, grid_y))

func get_grid_bounds() -> Vector2i:
	"""Get the grid dimensions (how many cells in x and y)"""
	return Vector2i(GAME_WIDTH / GRID_SIZE, GAME_HEIGHT / GRID_SIZE)
