# area_light.gd - Fixed collision shape alignment with immediate barrier response
extends Node2D
class_name AreaLight

@export var color_light: Color = Color.WHITE : set = set_light_color_export
@export var light_name: String = "AreaLight"
@export var cone_angle_degrees: float = 60.0 : set = set_cone_angle
@export var cone_length: float = 1000.0 : set = set_cone_length
@export var occlusion_check_points: int = 3
@export var debug_occlusion: bool = false : set = set_debug_occlusion
@export var light_length: float = 0.85

@onready var torch_light: PointLight2D = $TorchLight
@onready var light_area: Area2D = $LightDetectionArea
@onready var collision_polygon: CollisionPolygon2D = $LightDetectionArea/CollisionPolygon2D
@onready var sprite_2d: Sprite2D = $Sprite2D

var light_id: String = ""
var objects_in_area: Array = []
var confirmed_lit_objects: Array = []
var connected_barriers: Array = []  # Track which barriers we're listening to

func _ready() -> void:
	# Apply initial values
	torch_light.color = color_light
	sprite_2d.modulate = color_light
	torch_light.scale.y = light_length
	setup_light_detection_area()
	connect_signals()
	
	# Register with LightManager
	if LightManager:
		light_id = LightManager.register_light(self)
	
	# NEW: Only show sprite if parent node is named "Lights"
	var parent = get_parent()
	if parent.name != "Lights":
		sprite_2d.visible = false
		
	await get_tree().create_timer(0.5).timeout

func setup_light_detection_area():
	update_light_cone()

func connect_signals():
	if not light_area.area_entered.is_connected(_on_area_entered):
		light_area.area_entered.connect(_on_area_entered)
	if not light_area.area_exited.is_connected(_on_area_exited):
		light_area.area_exited.connect(_on_area_exited)
	if not light_area.body_entered.is_connected(_on_body_entered):
		light_area.body_entered.connect(_on_body_entered)
	if not light_area.body_exited.is_connected(_on_body_exited):
		light_area.body_exited.connect(_on_body_exited)

func update_light_cone():
	if not collision_polygon:
		return
	
	var points = PackedVector2Array()
	var cone_angle_rad = deg_to_rad(cone_angle_degrees)
	
	# Start at the origin (light source)
	points.append(Vector2.ZERO)
	
	var steps = 8
	for i in range(steps + 1):
		var angle_offset = -cone_angle_rad/2 + (cone_angle_rad * i / steps)
		
		# FIXED: Don't add rotation here since Area2D inherits rotation from parent
		# The collision shape will automatically rotate with the parent node
		var point = Vector2(sin(angle_offset), -cos(angle_offset)) * cone_length
		points.append(point)
	
	collision_polygon.polygon = points

func generate_light_cone_points() -> PackedVector2Array:
	var points = PackedVector2Array()
	var cone_angle_rad = deg_to_rad(cone_angle_degrees)
	
	points.append(Vector2.ZERO)
	
	var steps = 16
	for i in range(steps + 1):
		var angle = -cone_angle_rad/2 + (cone_angle_rad * i / steps)
		var point = Vector2(sin(angle), -cos(angle)) * cone_length
		points.append(point)
	
	return points

# Signal handlers
func _on_area_entered(area: Area2D):
	var parent = area.get_parent()
	if parent.is_in_group("barriers") or parent.is_in_group("lenses"):
		if not parent in objects_in_area:
			objects_in_area.append(parent)
			
			# Connect to barrier state changes if it's a barrier
			if parent.is_in_group("barriers") and parent.has_signal("passable_state_changed"):
				if not parent in connected_barriers:
					parent.passable_state_changed.connect(_on_barrier_state_changed)
					connected_barriers.append(parent)
		
		update_line_of_sight_check()

func _on_area_exited(area: Area2D):
	var parent = area.get_parent()
	if parent in objects_in_area:
		objects_in_area.erase(parent)
		
		# Disconnect from barrier if needed
		if parent in connected_barriers:
			if parent.passable_state_changed.is_connected(_on_barrier_state_changed):
				parent.passable_state_changed.disconnect(_on_barrier_state_changed)
			connected_barriers.erase(parent)
		
		if parent in confirmed_lit_objects:
			confirmed_lit_objects.erase(parent)
			_handle_object_unlit(parent)
		update_line_of_sight_check()

func _on_body_entered(body: Node2D):
	var parent = body.get_parent()
	if parent and (parent.is_in_group("barriers") or parent.is_in_group("lenses")):
		if not parent in objects_in_area:
			objects_in_area.append(parent)
			
			# Connect to barrier state changes if it's a barrier
			if parent.is_in_group("barriers") and parent.has_signal("passable_state_changed"):
				if not parent in connected_barriers:
					parent.passable_state_changed.connect(_on_barrier_state_changed)
					connected_barriers.append(parent)
		
		update_line_of_sight_check()

func _on_body_exited(body: Node2D):
	var parent = body.get_parent()
	if parent and parent in objects_in_area:
		objects_in_area.erase(parent)
		
		# Disconnect from barrier if needed
		if parent in connected_barriers:
			if parent.passable_state_changed.is_connected(_on_barrier_state_changed):
				parent.passable_state_changed.disconnect(_on_barrier_state_changed)
			connected_barriers.erase(parent)
		
		if parent in confirmed_lit_objects:
			confirmed_lit_objects.erase(parent)
			_handle_object_unlit(parent)
		update_line_of_sight_check()

# New function - immediate recheck when barriers change
func _on_barrier_state_changed():
	"""Force immediate line-of-sight recheck when any barrier changes state"""
	update_line_of_sight_check()

func update_line_of_sight_check():
	var new_confirmed_objects = []
	
	# Sort by distance
	var sorted_objects = objects_in_area.duplicate()
	sorted_objects.sort_custom(_compare_by_distance)
	
	# Check line of sight
	for obj in sorted_objects:
		if has_line_of_sight_to_object(obj):
			new_confirmed_objects.append(obj)
	
	_update_lighting_state(new_confirmed_objects)

func _compare_by_distance(a: Node2D, b: Node2D) -> bool:
	var dist_a = global_position.distance_squared_to(a.global_position)
	var dist_b = global_position.distance_squared_to(b.global_position)
	return dist_a < dist_b

func has_line_of_sight_to_object(target_object: Node2D) -> bool:
	"""Check if target object is visible (not occluded) from light source"""
	
	var check_points = _get_object_check_points(target_object)
	var visible_points = 0
	
	for i in range(check_points.size()):
		var check_point = check_points[i]
		if _is_point_visible(global_position, check_point, target_object):
			visible_points += 1
	
	var threshold = check_points.size() / 2.0
	var is_visible = visible_points >= threshold
	
	return is_visible

func _get_object_check_points(obj: Node2D) -> Array:
	var points = []
	points.append(obj.global_position)
	
	# Add more points based on object size if available
	var collision_shape = _find_collision_shape(obj)
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var shape = collision_shape.shape as RectangleShape2D
		var size = shape.size
		var half_width = size.x / 2
		var half_height = size.y / 2
		
		points.append(obj.global_position + Vector2(-half_width, 0))
		points.append(obj.global_position + Vector2(half_width, 0))
		if occlusion_check_points > 3:
			points.append(obj.global_position + Vector2(0, -half_height))
			points.append(obj.global_position + Vector2(0, half_height))
	
	return points

func _find_collision_shape(obj: Node2D) -> CollisionShape2D:
	for child in obj.get_children():
		if child is StaticBody2D or child is Area2D:
			for grandchild in child.get_children():
				if grandchild is CollisionShape2D:
					return grandchild
	return null

func _is_point_visible(from: Vector2, to: Vector2, target_object: Node2D = null) -> bool:
	"""Check if a specific point is visible from the light source"""
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(from, to)
	
	# Use a more specific collision mask - only check for walls and solid barriers
	# Layer 2 (Walls) = 2, Layer 3 (Player Collision Barriers) = 4
	query.collision_mask = 134  # Only walls (2) + player collision barriers (4)
	query.exclude = []
	
	# Exclude the target object we're checking visibility for
	if target_object:
		for child in target_object.get_children():
			if child is StaticBody2D or child is Area2D:
				query.exclude.append(child.get_rid())
	
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		return true
	
	var hit_object = result.collider
	var hit_position = result.position
	
	# Check if we hit a wall
	if hit_object.is_in_group("walls"):
		return false
		
	if hit_object.is_in_group("movable_blocks"):
		return false
	
	# Check if we hit a solid barrier (not the target)
	if hit_object.is_in_group("barriers"):
		var barrier = hit_object.get_parent()
		if barrier != target_object:  # Different barrier
			if barrier.has_method("should_block_light") and barrier.should_block_light():
				return false
	return true

func _update_lighting_state(new_confirmed_objects: Array):
	# Remove lighting from objects no longer visible
	for obj in confirmed_lit_objects:
		if not obj in new_confirmed_objects:
			_handle_object_unlit(obj)
	
	# Add lighting to newly visible objects
	for obj in new_confirmed_objects:
		if not obj in confirmed_lit_objects:
			_handle_object_lit(obj)
	
	confirmed_lit_objects = new_confirmed_objects


func _handle_object_lit(obj: Node2D):
	# Use the NEW generic LightManager functions
	if (obj.is_in_group("barriers") or obj.is_in_group("lenses")) and LightManager:
		LightManager.add_light_to_object(self, obj)  # Generic function!
	if obj.is_in_group("movable_blocks"):
		pass

func _handle_object_unlit(obj: Node2D):
	# Use the NEW generic LightManager functions
	if (obj.is_in_group("barriers") or obj.is_in_group("lenses")) and LightManager:
		LightManager.remove_light_from_object(self, obj)  # Generic function!
	if obj.is_in_group("movable_blocks") and LightManager:
		print("Remove Light from movable block")
		LightManager.remove_light_from_object(self, obj)

func _process(delta):
	# Periodic line of sight check (less frequent for performance)
	if Engine.get_process_frames() % 5 == 0:
		update_line_of_sight_check()

# Export property setters
func set_light_color_export(new_color: Color):
	color_light = new_color
	if torch_light:
		torch_light.color = new_color
	
	# Update barriers if LightManager exists
	if LightManager:
		for obj in confirmed_lit_objects:
			if obj.is_in_group("barriers"):
				LightManager.update_barrier_color(obj)

func set_cone_angle(new_angle: float):
	cone_angle_degrees = new_angle
	update_light_cone()

func set_cone_length(new_length: float):
	cone_length = new_length
	update_light_cone()

func set_debug_occlusion(enabled: bool):
	debug_occlusion = enabled
	queue_redraw()

# Debug visualization
func _draw():
	if not debug_occlusion:
		return
	
	for obj in objects_in_area:
		var color = Color.RED
		if obj in confirmed_lit_objects:
			color = Color.GREEN
		
		draw_line(Vector2.ZERO, to_local(obj.global_position), color, 2.0)

# Cleanup
func cleanup_connections():
	if light_area and is_instance_valid(light_area):
		if light_area.area_entered.is_connected(_on_area_entered):
			light_area.area_entered.disconnect(_on_area_entered)
		if light_area.area_exited.is_connected(_on_area_exited):
			light_area.area_exited.disconnect(_on_area_exited)
		if light_area.body_entered.is_connected(_on_body_entered):
			light_area.body_entered.disconnect(_on_body_entered)
		if light_area.body_exited.is_connected(_on_body_exited):
			light_area.body_exited.disconnect(_on_body_exited)
	
	# Clean up barrier connections
	for barrier in connected_barriers:
		if is_instance_valid(barrier) and barrier.has_signal("passable_state_changed"):
			if barrier.passable_state_changed.is_connected(_on_barrier_state_changed):
				barrier.passable_state_changed.disconnect(_on_barrier_state_changed)
	connected_barriers.clear()

func _exit_tree():
	cleanup_connections()
	if LightManager:
		LightManager.unregister_light(self)

func get_active_layers(collision_value: int) -> Array:
	var active_layers = []
	for i in range(1, 33):
		if collision_value & (1 << (i-1)):
			active_layers.append(i)
	return active_layers
