# light.gd - Updated to work with LightManager
extends Node2D
class_name Light

@export var color_light: Color
@export var light_name: String = "Light"
@onready var torch_light: PointLight2D = $TorchLight
@onready var raycasts: Node2D = $Raycasts

var raycast_array: Array = []
var light_id: String = ""

func _ready() -> void:
	torch_light.color = color_light
	
	for child in raycasts.get_children():
		if child is RayCast2D:
			raycast_array.append(child)
	
	# Register with LightManager
	if LightManager:
		light_id = LightManager.register_light(self)
	else:
		print("Warning: LightManager not found!")

func _physics_process(delta: float) -> void:
	# Let LightManager handle all collision processing
	if LightManager:
		LightManager.process_light_collisions(self, raycast_array)

# For backwards compatibility with lenses and other systems
func get_multiple_collisions(raycast: RayCast2D) -> Array:
	if LightManager:
		return LightManager.get_multiple_collisions(raycast)
	else:
		# Fallback to local implementation if LightManager is not available
		return _fallback_get_multiple_collisions(raycast)

# Fallback collision detection (simplified version of the old method)
func _fallback_get_multiple_collisions(raycast: RayCast2D) -> Array:
	var space_state = get_world_2d().direct_space_state
	var start_pos = raycast.global_position
	var end_pos = start_pos + raycast.target_position.rotated(raycast.global_rotation)
	
	var results = []
	var current_start = start_pos
	var max_iterations = 10
	var iteration = 0
	
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
		
		iteration += 1
	
	return results

# Clean up connections when light is removed
func cleanup_connections():
	# Override in subclasses if needed
	pass

func get_light_id() -> String:
	return light_id

# Get all barriers this light is currently affecting
func get_affected_barriers() -> Array:
	if LightManager:
		return LightManager.get_barriers_affected_by_light(self)
	return []

# Change light color dynamically
func set_light_color(new_color: Color):
	color_light = new_color
	torch_light.color = new_color
	
	# Update all affected barriers
	if LightManager:
		var affected_barriers = get_affected_barriers()
		for barrier in affected_barriers:
			LightManager.update_barrier_color(barrier)

func _exit_tree():
	cleanup_connections()
	# Unregister from LightManager
	if LightManager:
		LightManager.unregister_light(self)
