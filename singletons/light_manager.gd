# singletons/light_manager.gd - Refactored for generic object support
extends Node

# Dictionary to track all active lights in the scene
var active_lights: Dictionary = {}  # light_id -> Light node

# Dictionary to track object-light relationships (generic for any object type)
var object_light_map: Dictionary = {}  # object_node -> {light_source -> color}

# Performance optimization - cache collision results for a frame
var collision_cache: Dictionary = {}
var cache_frame: int = 0

# Generic light interaction events
signal light_hit_object(light: Node2D, object: Node2D, color: Color)
signal light_removed_from_object(light: Node2D, object: Node2D)
signal object_lighting_changed(object: Node2D, affecting_lights: Dictionary)

func _ready():
	print("Light Manager initialized")
	# Clear cache every frame
	get_tree().process_frame.connect(_clear_collision_cache)

func _clear_collision_cache():
	if Engine.get_process_frames() != cache_frame:
		collision_cache.clear()
		cache_frame = Engine.get_process_frames()

# Register a light source with the manager
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
		# Remove this light from all objects it was affecting
		for obj in object_light_map.keys():
			if object_light_map[obj].has(light):
				remove_light_from_object(light, obj)
		
		active_lights.erase(light_id)
		print("Unregistered light: ", light_id)

# Main function for raycast-based lights (backward compatibility)
func process_light_collisions(light: Node2D, raycast_array: Array):
	var new_hit_objects: Array = []
	
	# Get current objects this light was hitting
	var currently_hit_objects = []
	for obj in object_light_map.keys():
		if object_light_map[obj].has(light):
			currently_hit_objects.append(obj)
	
	# Check all raycasts for multiple collision hits
	for raycast in raycast_array:
		var multi_hits = get_multiple_collisions_optimized(raycast)
		
		for hit_info in multi_hits:
			var collider = hit_info.collider
			
			if collider and collider.is_in_group("walls"):
				break
				
			if collider and collider.is_in_group("movable_blocks"):
				break
				
			# Handle any light-reactive object (barriers, lenses, etc.)
			if collider and _is_light_reactive_object(collider):
				var obj = collider.get_parent()
				if obj and not obj in new_hit_objects:
					new_hit_objects.append(obj)
				
				# Check if this object blocks light (only barriers do this currently)
				if obj and obj.is_in_group("barriers") and obj.has_method("should_block_light") and obj.should_block_light():
					break
						
			# Old lens compatibility
			if collider and collider.is_in_group("lenses"):
				var lens = collider.get_parent()
				if lens.has_method("handle_light_hit"):
					lens.handle_light_hit(light, raycast)
	
	# Update lighting state
	_update_object_lighting(light, currently_hit_objects, new_hit_objects)

# Check if an object is light-reactive (barriers, lenses, future objects)
func _is_light_reactive_object(collider: Node2D) -> bool:
	return collider.is_in_group("barriers") or collider.is_in_group("lenses")

# Helper function to update object lighting state
func _update_object_lighting(light: Node2D, current_objects: Array, new_objects: Array):
	# Remove light from objects that are no longer being hit
	for obj in current_objects:
		if not obj in new_objects:
			remove_light_from_object(light, obj)
	
	# Add light to newly hit objects
	for obj in new_objects:
		if not obj in current_objects:
			add_light_to_object(light, obj)

# Add a light source to any object (generic)
func add_light_to_object(light: Node2D, obj: Node2D):
	if not object_light_map.has(obj):
		object_light_map[obj] = {}
	
	var light_color = _get_light_color(light)
	object_light_map[obj][light] = light_color
	
	# Let the object handle its own lighting response
	_notify_object_of_lighting_change(obj)
	
	# Emit signal
	light_hit_object.emit(light, obj, light_color)

# Remove a light source from any object (generic)
func remove_light_from_object(light: Node2D, obj: Node2D):
	if object_light_map.has(obj) and object_light_map[obj].has(light):
		object_light_map[obj].erase(light)
		
		# Clean up empty object entries
		if object_light_map[obj].is_empty():
			object_light_map.erase(obj)
		
		# Let the object handle its own lighting response
		_notify_object_of_lighting_change(obj)
		
		# Emit signal
		light_removed_from_object.emit(light, obj)

# Notify an object that its lighting has changed (polymorphic approach)
func _notify_object_of_lighting_change(obj: Node2D):
	var affecting_lights = {}
	if object_light_map.has(obj):
		affecting_lights = object_light_map[obj]
	
	# Different object types handle lighting differently
	if obj.is_in_group("barriers"):
		_handle_barrier_lighting(obj, affecting_lights)
	elif obj.is_in_group("lenses"):
		_handle_lens_lighting(obj, affecting_lights)
	
	# Emit generic signal
	object_lighting_changed.emit(obj, affecting_lights)

# Handle barrier-specific lighting (existing logic)
func _handle_barrier_lighting(barrier: Node2D, affecting_lights: Dictionary):
	if affecting_lights.is_empty():
		# No lights affecting this barrier
		if barrier.has_method("update_color_from_manager"):
			barrier.update_color_from_manager(barrier.barrier_color)
		return
	
	var final_color = barrier.barrier_color
	
	# Add all light colors to the barrier's base color
	for light_color in affecting_lights.values():
		final_color.r = min(final_color.r + light_color.r, 1.0)
		final_color.g = min(final_color.g + light_color.g, 1.0)
		final_color.b = min(final_color.b + light_color.b, 1.0)
	
	if barrier.has_method("update_color_from_manager"):
		barrier.update_color_from_manager(final_color)

# Handle lens-specific lighting (new)
func _handle_lens_lighting(lens: Node2D, affecting_lights: Dictionary):
	# Lenses don't use color mixing like barriers
	# They process each light individually through their own logic
	
	# For prisms specifically, we need to convert the affecting_lights into the format they expect
	if lens.has_method("handle_light_manager_update"):
		lens.handle_light_manager_update(affecting_lights)

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

# LEGACY FUNCTIONS - For backward compatibility
func add_light_to_barrier(light: Node2D, barrier: Node2D):
	add_light_to_object(light, barrier)

func remove_light_from_barrier(light: Node2D, barrier: Node2D):
	remove_light_from_object(light, barrier)

func update_barrier_color(barrier: Node2D):
	_notify_object_of_lighting_change(barrier)

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

# Scene management
func clear_all_lights():
	"""Call this when changing scenes or restarting levels"""
	for light in active_lights.values():
		if is_instance_valid(light) and light.has_method("cleanup_connections"):
			light.cleanup_connections()
	
	active_lights.clear()
	object_light_map.clear()
	collision_cache.clear()
	print("Light Manager cleared all data")

func _exit_tree():
	clear_all_lights()
