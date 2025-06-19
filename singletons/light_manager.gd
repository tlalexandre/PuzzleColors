# Updated LightManager.gd - Enhanced for Area2D light system
extends Node

# Dictionary to track all active lights in the scene
var active_lights: Dictionary = {}  # light_id -> Light node

# Dictionary to track barrier-light relationships
var barrier_light_map: Dictionary = {}  # barrier_node -> {light_source -> color}

# Performance optimization - cache collision results for a frame
var collision_cache: Dictionary = {}
var cache_frame: int = 0

# Light interaction events
signal light_hit_barrier(light: Node2D, barrier: Node2D, color: Color)
signal light_removed_from_barrier(light: Node2D, barrier: Node2D)
signal barrier_color_changed(barrier: Node2D, new_color: Color)

func _ready():
	print("Light Manager initialized")
	# Clear cache every frame
	get_tree().process_frame.connect(_clear_collision_cache)

func _clear_collision_cache():
	if Engine.get_process_frames() != cache_frame:
		collision_cache.clear()
		cache_frame = Engine.get_process_frames()

# Register a light source with the manager (works with both raycast and area2d lights)
func register_light(light: Node2D) -> String:
	var light_id = _generate_light_id(light)
	active_lights[light_id] = light
	
	var light_name = light.light_name if light.has_method("get") and light.get("light_name") else "Unknown"
	print("Registered light: ", light_id, " (", light_name, ")")
	return light_id

# Unregister a light source
func unregister_light(light: Node2D):
	var light_id = _find_light_id(light)
	if light_id != "":
		# Remove this light from all barriers it was affecting
		for barrier in barrier_light_map.keys():
			if barrier_light_map[barrier].has(light):
				remove_light_from_barrier(light, barrier)
		
		active_lights.erase(light_id)
		print("Unregistered light: ", light_id)

# Main function for raycast-based lights (backward compatibility)
func process_light_collisions(light: Node2D, raycast_array: Array):
	var new_hit_barriers: Array = []
	
	# Get current barriers this light was hitting
	var currently_hit_barriers = []
	for barrier in barrier_light_map.keys():
		if barrier_light_map[barrier].has(light):
			currently_hit_barriers.append(barrier)
	
	# Check all raycasts for multiple collision hits
	for raycast in raycast_array:
		var multi_hits = get_multiple_collisions_optimized(raycast)
		
		for hit_info in multi_hits:
			var collider = hit_info.collider
			
			if collider and collider.is_in_group("walls"):
				break
				
			if collider and collider.is_in_group("movable_blocks"):
				break
				
			if collider and collider.is_in_group("barriers"):
				var barrier = collider.get_parent()
				if barrier and not barrier in new_hit_barriers:
					new_hit_barriers.append(barrier)
				
				if barrier and barrier.should_block_light():
					break
						
			if collider and collider.is_in_group("lenses"):
				var lens = collider.get_parent()
				lens.handle_light_hit(light, raycast)
	
	# Update lighting state
	_update_barrier_lighting(light, currently_hit_barriers, new_hit_barriers)

# New function for area2d-based lights
func process_area_light_collisions(light: Node2D, confirmed_barriers: Array):
	# Get current barriers this light was hitting
	var currently_hit_barriers = []
	for barrier in barrier_light_map.keys():
		if barrier_light_map[barrier].has(light):
			currently_hit_barriers.append(barrier)
	
	# Update lighting state
	_update_barrier_lighting(light, currently_hit_barriers, confirmed_barriers)

# Helper function to update barrier lighting state
func _update_barrier_lighting(light: Node2D, current_barriers: Array, new_barriers: Array):
	# Remove light from barriers that are no longer being hit
	for barrier in current_barriers:
		if not barrier in new_barriers:
			remove_light_from_barrier(light, barrier)
	
	# Add light to newly hit barriers
	for barrier in new_barriers:
		if not barrier in current_barriers:
			add_light_to_barrier(light, barrier)

# Add a light source to a barrier
func add_light_to_barrier(light: Node2D, barrier: Node2D):
	if not barrier_light_map.has(barrier):
		barrier_light_map[barrier] = {}
	
	var light_color = _get_light_color(light)
	barrier_light_map[barrier][light] = light_color
	
	# Update barrier's color
	update_barrier_color(barrier)
	
	# Emit signal
	light_hit_barrier.emit(light, barrier, light_color)

# Remove a light source from a barrier
func remove_light_from_barrier(light: Node2D, barrier: Node2D):
	if barrier_light_map.has(barrier) and barrier_light_map[barrier].has(light):
		barrier_light_map[barrier].erase(light)
		
		# Clean up empty barrier entries
		if barrier_light_map[barrier].is_empty():
			barrier_light_map.erase(barrier)
		
		# Update barrier's color
		update_barrier_color(barrier)
		
		# Emit signal
		light_removed_from_barrier.emit(light, barrier)

# Calculate and update a barrier's final color based on all affecting lights
func update_barrier_color(barrier: Node2D):
	if not barrier_light_map.has(barrier):
		# No lights affecting this barrier
		if barrier.has_method("update_color_from_manager"):
			barrier.update_color_from_manager(barrier.barrier_color)
		return
	
	var final_color = barrier.barrier_color
	
	# Add all light colors to the barrier's base color
	for light_color in barrier_light_map[barrier].values():
		final_color.r = min(final_color.r + light_color.r, 1.0)
		final_color.g = min(final_color.g + light_color.g, 1.0)
		final_color.b = min(final_color.b + light_color.b, 1.0)
	
	if barrier.has_method("update_color_from_manager"):
		barrier.update_color_from_manager(final_color)
	barrier_color_changed.emit(barrier, final_color)


# Helper function to get light color from any light type
func _get_light_color(light: Node2D) -> Color:
	# Check if the light has a color_light property
	if "color_light" in light:
		return light.color_light
	
	# Fallback for different light types
	if light.has_method("get_light_color"):
		return light.get_light_color()
	
	# Check if it's an old Light class with color_light
	var color_prop = light.get("color_light")
	if color_prop != null and color_prop is Color:
		return color_prop
	
	print("Warning: Could not get color from light ", light.name, " - using white")
	return Color.WHITE

# Optimized collision detection with caching (for raycast lights)
func get_multiple_collisions_optimized(raycast: RayCast2D) -> Array:
	var cache_key = str(raycast.get_instance_id()) + "_" + str(raycast.global_position) + "_" + str(raycast.global_rotation)
	
	if collision_cache.has(cache_key):
		return collision_cache[cache_key]
	
	var results = get_multiple_collisions(raycast)
	collision_cache[cache_key] = results
	return results

# The actual collision detection logic (for backward compatibility)
func get_multiple_collisions(raycast: RayCast2D) -> Array:
	var space_state = raycast.get_world_2d().direct_space_state
	var start_pos = raycast.global_position
	var end_pos = start_pos + raycast.target_position.rotated(raycast.global_rotation)
	
	var results = []
	var current_start = start_pos
	var max_iterations = 20
	var iteration = 0
	var total_distance = start_pos.distance_to(end_pos)
	
	while iteration < max_iterations:
		var query = PhysicsRayQueryParameters2D.create(current_start, end_pos)
		query.collision_mask = raycast.collision_mask
		query.hit_from_inside = raycast.hit_from_inside
		query.collide_with_areas = raycast.collide_with_areas
		
		var result = space_state.intersect_ray(query)
		
		if result.is_empty():
			break
			
		results.append(result)
		
		var collision_point = result.position
		var direction = (end_pos - start_pos).normalized()
		current_start = collision_point + direction * 2.0
		
		var traveled_distance = start_pos.distance_to(current_start)
		if traveled_distance >= total_distance * 0.98:
			break
			
		iteration += 1
	
	return results

# Utility functions
func _generate_light_id(light: Node2D) -> String:
	var name = light.name if light.name else "UnknownLight"
	return str(light.get_instance_id()) + "_" + name

func _find_light_id(light: Node2D) -> String:
	var target_id = light.get_instance_id()
	for light_id in active_lights.keys():
		if active_lights[light_id].get_instance_id() == target_id:
			return light_id
	return ""

# Get all lights affecting a specific barrier
func get_lights_affecting_barrier(barrier: Node2D) -> Array:
	if not barrier_light_map.has(barrier):
		return []
	return barrier_light_map[barrier].keys()

# Get all barriers affected by a specific light
func get_barriers_affected_by_light(light: Node2D) -> Array:
	var affected_barriers = []
	for barrier in barrier_light_map.keys():
		if barrier_light_map[barrier].has(light):
			affected_barriers.append(barrier)
	return affected_barriers

# Debug functions
func get_total_active_lights() -> int:
	return active_lights.size()

func get_total_affected_barriers() -> int:
	return barrier_light_map.size()

func print_debug_info():
	print("=== Light Manager Debug ===")
	print("Active lights: ", active_lights.size())
	print("Affected barriers: ", barrier_light_map.size())
	for barrier in barrier_light_map.keys():
		print("  Barrier ", barrier.name, " affected by ", barrier_light_map[barrier].size(), " lights")

# Color utility functions
func mix_colors(color1: Color, color2: Color) -> Color:
	return Color(
		min(color1.r + color2.r, 1.0),
		min(color1.g + color2.g, 1.0),
		min(color1.b + color2.b, 1.0),
		color1.a
	)

func colors_approximately_equal(color1: Color, color2: Color, tolerance: float = 0.1) -> bool:
	return (
		abs(color1.r - color2.r) < tolerance and
		abs(color1.g - color2.g) < tolerance and
		abs(color1.b - color2.b) < tolerance
	)

# Scene management
func clear_all_lights():
	"""Call this when changing scenes or restarting levels"""
	for light in active_lights.values():
		if is_instance_valid(light) and light.has_method("cleanup_connections"):
			light.cleanup_connections()
	
	active_lights.clear()
	barrier_light_map.clear()
	collision_cache.clear()
	print("Light Manager cleared all data")

func _exit_tree():
	clear_all_lights()
