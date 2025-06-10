extends Node2D
var current_frame_hits: Array = []
var deflection_angles: Array = [45.0, 0.0, -45.0]
var refracted_raycasts: Array = []

func _ready():
	add_to_group("lenses")

func _draw():
	# Draw lines for each refracted raycast
	for raycast in refracted_raycasts:
		if raycast and is_instance_valid(raycast):
			var start_pos = to_local(raycast.global_position)
			var end_pos = start_pos + raycast.target_position
			
			# Draw the full ray line (whether colliding or not)
			draw_line(start_pos, end_pos, Color.CYAN, 6.0)
			
			# If hitting something, draw collision point
			if raycast.is_colliding():
				var collision_point = to_local(raycast.get_collision_point())
				draw_line(start_pos, collision_point, Color.MAGENTA, 6.0)
				draw_circle(collision_point, 6, Color.YELLOW)

func _physics_process(delta):
	if current_frame_hits.size() > 0:
		update_refracted_rays()
		current_frame_hits.clear()
	else:
		clear_refracted_rays()
	
	# Check for refracted ray collisions
	check_refracted_ray_collisions()
	
	queue_redraw()

func check_refracted_ray_collisions():
	for i in range(refracted_raycasts.size()):
		var raycast = refracted_raycasts[i]
		if raycast and raycast.is_colliding():
			var collider = raycast.get_collider()
			var collision_point = raycast.get_collision_point()
			
			print("Refracted ray ", i, " hit: ", collider.name if collider else "unknown")
			print("  Collision point: ", collision_point)
			
			# Check what type of object was hit
			if collider:
				if collider.is_in_group("walls"):
					print("  Hit a wall!")
				elif collider.is_in_group("barriers"):
					print("  Hit a barrier!")
				elif collider.is_in_group("lenses"):
					print("  Hit another lens!")

func handle_light_hit(light_source, raycast):
	var light_position = light_source.global_position
	var hit_point = raycast.get_collision_point()
	var actual_direction = (hit_point - light_position).normalized()
	
	var hit_data = {
		"light_source": light_source,
		"raycast": raycast,
		"hit_point": hit_point,
		"original_direction": actual_direction,
		"light_color": light_source.color_light
	}
	
	current_frame_hits.append(hit_data)

func update_refracted_rays():
	clear_refracted_rays()
	
	for i in range(current_frame_hits.size()):
		var hit = current_frame_hits[i]
		
		var incoming_angle = atan2(hit.original_direction.y, hit.original_direction.x)
		var incoming_degrees = rad_to_deg(incoming_angle)
		var new_angle_degrees = incoming_degrees + deflection_angles[i]
		var new_angle_radians = deg_to_rad(new_angle_degrees)
		var new_direction = Vector2(cos(new_angle_radians), sin(new_angle_radians))
		
		var lens_center = global_position
		var lens_width = 1.0
		var exit_point = Vector2(lens_center.x + lens_width, hit.hit_point.y)
		
		create_refracted_ray(exit_point, new_direction, hit.light_color)

func create_refracted_ray(start_point: Vector2, direction: Vector2, light_color: Color):
	var new_raycast = RayCast2D.new()
	add_child(new_raycast)
	
	new_raycast.global_position = start_point
	new_raycast.target_position = direction * 1000
	new_raycast.collision_mask = 82
	new_raycast.hit_from_inside = true
	new_raycast.collide_with_areas = true
	
	new_raycast.set_meta("light_color", light_color)
	refracted_raycasts.append(new_raycast)

func clear_refracted_rays():
	for ray in refracted_raycasts:
		if is_instance_valid(ray):
			ray.queue_free()
	refracted_raycasts.clear()
