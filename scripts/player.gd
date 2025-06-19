extends CharacterBody2D
@export var push_force: float = 120.0
@export var min_push_velocity: float = 50.0
var speed: float = 500.0
var direction: Vector2 # This will store the normalized direction of movement
@onready var area_2d_light: Node2D = $Area2dLight
@onready var area_2d: Area2D = $Area2D # Assuming this Area2D is for detecting pushable blocks

var colliding_movable_blocks: Array[Node2D] = [] # Keep this for potential future uses, but it's not strictly needed for this specific push logic

func _physics_process(delta: float) -> void:
	# 1. Capture input direction first
	direction = Vector2.ZERO # Reset direction each frame
	if Input.is_action_pressed("up"):
		direction.y -= 1
	if Input.is_action_pressed("down"):
		direction.y += 1
	if Input.is_action_pressed("right"):
		direction.x += 1
	if Input.is_action_pressed("left"):
		direction.x -= 1

	# Normalize the direction to ensure consistent speed when moving diagonally
	if direction.length() > 0:
		direction = direction.normalized()
	
	# 2. Calculate velocity based on the captured direction and speed
	velocity = direction * speed
	
	# Make torchlight face mouse position
	var mouse_pos = get_global_mouse_position()
	var direction_to_mouse = global_position.direction_to(mouse_pos)
	area_2d_light.rotation = direction_to_mouse.angle()
	
	# Perform the movement and get collision information
	move_and_slide()

	# Check for direct collisions and apply push impulse
	if direction.length() > 0: # Only push if the player is actively moving
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider_body = collision.get_collider()

			if collider_body and collider_body.is_in_group("movable_blocks"):
				# Ensure the collision normal is roughly in the direction of player movement
				# This prevents pushing blocks you're just sliding past or are "behind" you
				var collision_normal = collision.get_normal()
				var player_to_block_direction = (collider_body.global_position - global_position).normalized()

				# Option 1: Simple check against player movement direction (best for direct pushing)
				# If the dot product is negative, the block is generally in front of the player's movement direction
				# and the player's movement vector is "against" the collision normal.
				# A dot product close to -1 means they are directly opposite.
				if direction.dot(-collision_normal) > 0.7: # Adjust 0.7 to fine-tune the "push angle"
					collider_body.apply_push_impulse(direction, push_force)

				# Option 2: Consider the actual contact point and relative direction (more complex, but robust)
				# This is often handled well by the engine's physics if only applying force on direct contact.
				# For simpler top-down pushes, Option 1 is usually sufficient and avoids accidental pushes.


# The _on_area_2d_body_entered and _on_area_2d_body_exited functions are still useful
# if you want to know which blocks are *near* the player for other game logic (e.g., UI prompts).
# However, for the pushing mechanism itself, checking `get_slide_collision` is more precise.
# You can remove the `colliding_movable_blocks` array and these functions if their only purpose
# was to facilitate the push, as `get_slide_collision` provides more accurate, frame-by-frame contact info.
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("movable_blocks"):
		if not colliding_movable_blocks.has(body):
			colliding_movable_blocks.append(body)

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("movable_blocks"):
		if colliding_movable_blocks.has(body):
			colliding_movable_blocks.erase(body)
