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
