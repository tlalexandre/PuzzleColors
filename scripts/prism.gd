# prism.gd - Updated for generic LightManager system
extends Node2D
class_name Prism

# Configuration
@export var combine_time_window: float = 0.15  # Simultaneous detection window
@export var output_beam_length: float = 600.0  # How far beams reach
@export var output_beam_width: float = 30.0    # Cone angle of output beams
@export var debug_mode: bool = false           # Show debug visualization

@onready var detection_area: Area2D = $DetectionArea
@onready var collision_shape: CollisionPolygon2D = $DetectionArea/CollisionPolygon2D

# State tracking
var current_input_lights: Dictionary = {}      # light_node -> {color: Color, time: float}
var generated_output_beams: Array = []         # Created Area2dLight instances
var last_input_time: float = 0.0
var processing_timer: Timer
var prism_created_lights: Array = []           # Track lights created by THIS prism

func _ready():
	add_to_group("lenses")
	
	# Connect to NEW generic LightManager signals
	if LightManager:
		LightManager.light_hit_object.connect(_on_light_hit_object)
		LightManager.light_removed_from_object.connect(_on_light_removed_from_object)
	else:
		print("Warning: LightManager not found!")
	
	# Create processing timer
	processing_timer = Timer.new()
	processing_timer.wait_time = combine_time_window
	processing_timer.one_shot = true
	processing_timer.timeout.connect(_process_prism_logic)
	add_child(processing_timer)
	
	print("Prism initialized at: ", global_position)

# Called by LightManager when a light hits any object (generic)
func _on_light_hit_object(light: Node2D, target: Node2D, color: Color):
	if target == self:
		# PREVENT FEEDBACK: Don't accept light from our own output beams
		if light in prism_created_lights:
			if debug_mode:
				print("Prism: Ignoring feedback from own output beam")
			return
		
		_add_input_light(light, color)
		if debug_mode:
			print("Prism: Light hit detected via LightManager - color: ", color)

# Called by LightManager when a light stops hitting any object (generic)
func _on_light_removed_from_object(light: Node2D, target: Node2D):
	if target == self:
		_remove_input_light(light)
		if debug_mode:
			print("Prism: Light removed via LightManager")

# NEW: Handle bulk lighting updates from LightManager (polymorphic approach)
func handle_light_manager_update(affecting_lights: Dictionary):
	"""Called by LightManager when the lighting state changes"""
	
	# Convert LightManager format back to our internal format
	current_input_lights.clear()
	var current_time = Time.get_ticks_msec() / 1000.0
	
	for light in affecting_lights.keys():
		# PREVENT FEEDBACK: Don't accept light from our own output beams
		if light in prism_created_lights:
			continue
			
		current_input_lights[light] = {
			"color": affecting_lights[light],
			"time": current_time
		}
	
	# Process immediately since this is a bulk update
	_process_prism_logic()

# Add an input light
func _add_input_light(light: Node2D, light_color: Color):
	if not light:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0  # More precise timing
	
	current_input_lights[light] = {
		"color": light_color,
		"time": current_time
	}
	
	last_input_time = current_time
	
	if debug_mode:
		print("Prism: Added input light with color ", light_color)
	
	# Restart the processing timer to wait for more simultaneous lights
	processing_timer.start()

# Remove an input light
func _remove_input_light(light: Node2D):
	if light in current_input_lights:
		current_input_lights.erase(light)
		if debug_mode:
			print("Prism: Removed input light")
		
		# If no lights left, clear outputs
		if current_input_lights.is_empty():
			_clear_output_beams()
		else:
			# Reprocess with remaining lights
			processing_timer.start()

# Main prism logic processor
func _process_prism_logic():
	if current_input_lights.is_empty():
		_clear_output_beams()
		return
	
	_clear_output_beams()  # Remove old outputs
	
	if debug_mode:
		print("Prism: Processing with ", current_input_lights.size(), " input lights")
	
	if current_input_lights.size() == 1:
		# Single light input - check if we should split it
		var light_data = current_input_lights.values()[0]
		_handle_single_light_input(light_data.color)
	else:
		# Multiple light inputs - combine them
		_handle_multiple_light_inputs()

# Handle single light input (splitting logic)
func _handle_single_light_input(input_color: Color):
	var split_colors = _get_color_components(input_color)
	
	if debug_mode:
		print("Prism: Split ", input_color, " into ", split_colors.size(), " components")
	
	if split_colors.size() <= 1:
		# Pure color → pass through unchanged
		_create_output_beam(input_color, 0.0)
	else:
		# Mixed color → split into components
		# FIXED: Better angle distribution for 2 or 3 components
		if split_colors.size() == 2:
			# Two colors: spread at ±30 degrees
			_create_output_beam(split_colors[0], deg_to_rad(-30.0))
			_create_output_beam(split_colors[1], deg_to_rad(30.0))
		else:
			# Three colors: spread at -30, 0, +30 degrees  
			_create_output_beam(split_colors[0], deg_to_rad(-30.0))
			_create_output_beam(split_colors[1], deg_to_rad(0.0))
			_create_output_beam(split_colors[2], deg_to_rad(30.0))

# Handle multiple light inputs (combining logic)
func _handle_multiple_light_inputs():
	var combined_color = Color.BLACK
	
	# Additive color mixing
	for light_data in current_input_lights.values():
		var color = light_data.color
		combined_color.r = min(combined_color.r + color.r, 1.0)
		combined_color.g = min(combined_color.g + color.g, 1.0)
		combined_color.b = min(combined_color.b + color.b, 1.0)
	
	if debug_mode:
		print("Prism: Combined ", current_input_lights.size(), " lights into ", combined_color)
	
	# Output combined result straight ahead
	_create_output_beam(combined_color, 0.0)

# Get the pure color components of a mixed color
func _get_color_components(color: Color) -> Array:
	var components = []
	var tolerance = 0.1
	
	# Check for red component
	if color.r > tolerance:
		components.append(Color.RED)
	
	# Check for green component
	if color.g > tolerance:
		components.append(Color.GREEN)
	
	# Check for blue component
	if color.b > tolerance:
		components.append(Color.BLUE)
	
	return components

# Create an output beam using Area2dLight
func _create_output_beam(color: Color, angle_offset: float):
	# Load the Area2dLight scene
	var area_light_scene = load("res://scenes/area2d_light.tscn")
	if not area_light_scene:
		print("Error: Could not load area2d_light.tscn")
		return
	
	var output_beam = area_light_scene.instantiate()
	get_parent().add_child(output_beam)
	
	# Position and orient the beam
	output_beam.global_position = global_position
	output_beam.rotation = rotation + angle_offset
	
	# Configure the beam properties
	output_beam.set_light_color_export(color)
	output_beam.set_cone_length(output_beam_length)
	output_beam.set_cone_angle(output_beam_width)
	
	# Track the created beam to prevent feedback
	generated_output_beams.append(output_beam)
	prism_created_lights.append(output_beam)
	
	if debug_mode:
		print("Prism: Created output beam with color ", color, " at angle ", rad_to_deg(angle_offset))

# Clear all output beams
func _clear_output_beams():
	for beam in generated_output_beams:
		if is_instance_valid(beam):
			# Remove from tracking list
			if beam in prism_created_lights:
				prism_created_lights.erase(beam)
			beam.queue_free()
	generated_output_beams.clear()

# Handle light hit from old raycast system (for compatibility)
func handle_light_hit(light_source, raycast):
	# PREVENT FEEDBACK: Don't accept light from our own output beams
	if light_source in prism_created_lights:
		return
		
	var light_color = Color.WHITE
	if "color_light" in light_source:
		light_color = light_source.color_light
	_add_input_light(light_source, light_color)

# Debug visualization
func _draw():
	if not debug_mode:
		return
	
	# Draw detection area
	draw_circle(Vector2.ZERO, 50, Color.YELLOW, false, 2.0)
	
	# Draw lines to input lights
	for light in current_input_lights.keys():
		if is_instance_valid(light):
			var light_color = current_input_lights[light].color
			draw_line(Vector2.ZERO, to_local(light.global_position), light_color, 3.0)
	
	# Draw output beam directions
	for i in range(generated_output_beams.size()):
		var beam = generated_output_beams[i]
		if is_instance_valid(beam):
			var direction = Vector2(0, -50).rotated(beam.rotation - rotation)
			draw_line(Vector2.ZERO, direction, beam.color_light, 4.0)

# Cleanup when removed
func cleanup():
	if LightManager:
		if LightManager.light_hit_object.is_connected(_on_light_hit_object):
			LightManager.light_hit_object.disconnect(_on_light_hit_object)
		if LightManager.light_removed_from_object.is_connected(_on_light_removed_from_object):
			LightManager.light_removed_from_object.disconnect(_on_light_removed_from_object)

func _exit_tree():
	_clear_output_beams()
	cleanup()
