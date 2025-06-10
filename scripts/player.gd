extends CharacterBody2D
var speed: float = 500.0
@onready var straight_light: Node2D = $StraightLight

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
	straight_light.rotation = direction_to_mouse.angle() + deg_to_rad(90)
	
	move_and_slide()
