# movable_block.gd
extends RigidBody2D
class_name MovableBlock

@export var push_strength: float = 1000.0
@export var linear_damp_override: float = 8.0
var grid_size: int = 64
var snap_threshold: float = 50.0  # Speed below which we snap to grid

func _ready():
	# Set physics properties
	gravity_scale = 0  # No gravity for top-down game
	linear_damp = linear_damp_override
	lock_rotation = true  # Prevent rotation
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC

func _physics_process(delta):
	# Snap to grid when moving slowly
	if linear_velocity.length() < snap_threshold:
		snap_to_grid()

func push_from_direction(direction: Vector2, force: float = push_strength):
	"""Apply a push force in the given direction"""
	var impulse = direction.normalized() * force
	apply_central_impulse(impulse)

func snap_to_grid():
	"""Snap position to the nearest grid point when nearly stopped"""
	var current_pos = global_position
	var snapped_pos = Vector2(
		round(current_pos.x / grid_size) * grid_size,
		round(current_pos.y / grid_size) * grid_size
	)
	
	# Only snap if we're close enough and moving slowly
	if current_pos.distance_to(snapped_pos) < grid_size * 0.4 and linear_velocity.length() < snap_threshold:
		global_position = snapped_pos
		linear_velocity = Vector2.ZERO

func can_be_pushed_to(direction: Vector2) -> bool:
	"""Check if the block can be pushed in the given direction"""
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + direction.normalized() * (grid_size * 0.8)
	)
	query.collision_mask = collision_mask
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func _on_body_entered(body):
	"""Handle collisions with other bodies"""
	if body.is_in_group("player"):
		# Calculate push direction from player to block
		var push_dir = (global_position - body.global_position).normalized()
		push_from_direction(push_dir, push_strength * 0.5)
