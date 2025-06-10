extends Light
@onready var torch_light_player: PointLight2D = $TorchLight

func _ready():
	super._ready()


func _draw():
	# Draw lines for each raycast
	for raycast in raycast_array:
		if raycast:
			# If the raycast is hitting something, draw to the collision point
			if raycast.is_colliding():
				var start_pos = raycast.position
				var collision_point = to_local(raycast.get_collision_point())
				draw_line(start_pos, collision_point, Color.RED, 3.0)
				
				# Draw a small circle at the collision point
				draw_circle(collision_point, 3, Color.YELLOW)

func _physics_process(delta):
	# Call parent physics process
	super._physics_process(delta)
	
	# Force redraw every frame to update the lines
	queue_redraw()
