extends CharacterBody2D
var speed: float = 500.0
#@onready var straight_light: Node2D = $StraightLight
@onready var area_2d_light: Node2D = $Area2dLight

func _physics_process(delta: float) -> void:
	velocity = Vector2.ZERO
	
	if Input.is_action_pressed("up"):
		velocity.y -= speed
		
	if Input.is_action_pressed("down"):
		velocity.y += speed
	
	if Input.is_action_pressed("right"):
		velocity.x += speed
		
	if Input.is_action_pressed("left"):
		velocity.x -= speed
	
	# Make torchlight face mouse position
	var mouse_pos = get_global_mouse_position()
	var direction_to_mouse = global_position.direction_to(mouse_pos)
	area_2d_light.rotation = direction_to_mouse.angle()
	
	move_and_slide()
	check_for_pushable_blocks()

func check_for_pushable_blocks():
	"""Check if we're touching any movable blocks and push them"""
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider and collider.is_in_group("movable_blocks"):
			var block = collider as MovableBlock
			if block:
				# Calculate push direction (from player to block)
				var push_direction = collision.get_normal() * -1
				
				# Check if block can be pushed in that direction
				if block.can_be_pushed_to(push_direction):
					# Apply push force
					block.push_from_direction(push_direction, block.push_strength)
