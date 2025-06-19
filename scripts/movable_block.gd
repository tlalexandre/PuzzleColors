extends RigidBody2D
class_name MoveableBlock


@export var push_force_multiplier: float = 3

func apply_push_impulse(direction: Vector2, force: float):
	# Method for external pushing (called by player)
	var impulse = direction.normalized() * force * push_force_multiplier
	apply_central_force(impulse)
