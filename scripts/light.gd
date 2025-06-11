extends Node2D
class_name Light
@export var color_light: Color
@export var light_name: String = "Light"
@onready var torch_light: PointLight2D = $TorchLight
@onready var raycasts: Node2D = $Raycasts
var raycast_array: Array = []
var currently_hit_barriers: Array = []

func _ready() -> void:
	torch_light.color = color_light
	
	for child in raycasts.get_children():
		if child is RayCast2D:
			raycast_array.append(child)

func _physics_process(delta: float) -> void:
	var new_hit_barriers: Array = []
	
	# Check all raycasts for multiple collision hits
	for raycast in raycast_array:
		var multi_hits = get_multiple_collisions(raycast)
		
		for hit_info in multi_hits:
			var collider = hit_info.collider
			
			if collider and collider.is_in_group("walls"):
				# Wall blocks everything behind it, stop checking further hits on this raycast
				break
				
			if collider and collider.is_in_group("barriers"):
				var barrier = collider.get_parent()
				if barrier and not barrier in new_hit_barriers:
					# Always add the barrier to the hit list first
					new_hit_barriers.append(barrier)
				
				# Check if this barrier should block further detection
				if barrier and barrier.should_block_light():
					# This barrier is solid, stop checking further on this raycast
					break
				# If barrier is passable (white), continue to next collision
						
			if collider and collider.is_in_group("lenses"):
				var lens = collider.get_parent()
				# For lenses, we'll use the original raycast for compatibility
				lens.handle_light_hit(self, raycast)
				# Continue checking behind the lens
	
	# Remove light from barriers that are no longer being hit
	for barrier in currently_hit_barriers:
		if not barrier in new_hit_barriers:
			barrier.remove_light(self)
	
	# Add light to newly hit barriers
	for barrier in new_hit_barriers:
		if not barrier in currently_hit_barriers:
			barrier.add_light(self, color_light)
	
	# Update the list of currently hit barriers
	currently_hit_barriers = new_hit_barriers

func get_multiple_collisions(raycast: RayCast2D) -> Array:
	var space_state = get_world_2d().direct_space_state
	var start_pos = raycast.global_position
	var end_pos = start_pos + raycast.target_position.rotated(raycast.global_rotation)
	
	var results = []
	var current_start = start_pos
	var max_iterations = 20  # Increase iterations for more thorough detection
	var iteration = 0
	var total_distance = start_pos.distance_to(end_pos)
	
	while iteration < max_iterations:
		# Create a fresh query for each iteration
		var query = PhysicsRayQueryParameters2D.create(current_start, end_pos)
		query.collision_mask = raycast.collision_mask
		query.hit_from_inside = raycast.hit_from_inside
		query.collide_with_areas = raycast.collide_with_areas
		
		# Cast ray from current position
		var result = space_state.intersect_ray(query)
		
		if result.is_empty():
			break
			
		results.append(result)
		
		# Move start position past the collision point for next iteration
		var collision_point = result.position
		var direction = (end_pos - start_pos).normalized()
		current_start = collision_point + direction * 2.0  # Move 2 pixels past collision
		
		# If we've traveled most of the ray distance, stop
		var traveled_distance = start_pos.distance_to(current_start)
		if traveled_distance >= total_distance * 0.98:  # 98% of total distance
			break
			
		iteration += 1
		
	
	return results

func _exit_tree():
	# Clean up when light is removed from scene
	for barrier in currently_hit_barriers:
		barrier.remove_light(self)
