extends Node2D
@export var barrier_color: Color = Color.RED
@export var target_color: Color = Color.WHITE
@export var color_tolerance: float = 0.15
var active_lights: Dictionary = {}  # source_node -> color
@onready var color_rect: ColorRect = $ColorRect
@onready var static_body: StaticBody2D = $StaticBody2D
@onready var light_occluder_2d: LightOccluder2D = $LightOccluder2D
var original_occluder: OccluderPolygon2D

# Hysteresis thresholds to prevent flickering
var match_threshold: float = 0.15      # Need to be within this distance to become passable
var no_match_threshold: float = 0.25   # Need to be further than this to become non-passable
var is_currently_passable: bool = false

func _ready() -> void:
	color_rect.color = barrier_color
	original_occluder = light_occluder_2d.occluder
	
func _process(delta: float) -> void:
	update_color()
	update_collision()

func add_light(source_node, light_color: Color):
	active_lights[source_node] = light_color
	
func remove_light(source_node):
	if source_node in active_lights:
		active_lights.erase(source_node)

func update_color():
	var final_color = barrier_color
	
	# Add all light colors to the barrier's base color
	for light_color in active_lights.values():
		final_color.r = min(final_color.r + light_color.r, 1.0)
		final_color.g = min(final_color.g + light_color.g, 1.0)
		final_color.b = min(final_color.b + light_color.b, 1.0)
	
	color_rect.color = final_color

func is_color_match(current: Color, target: Color, tolerance: float) -> bool:
	var distance = sqrt(
		pow(current.r - target.r, 2) + 
		pow(current.g - target.g, 2) + 
		pow(current.b - target.b, 2)
	)
	return distance < tolerance

func update_collision():
	var current_color = color_rect.color
	
	# Hysteresis logic: different thresholds for becoming passable vs non-passable
	if not is_currently_passable:
		# Not passable yet - check if we should become passable (stricter threshold)
		if is_color_match(current_color, target_color, match_threshold):
			is_currently_passable = true
	else:
		# Currently passable - check if we should become non-passable (looser threshold)
		if not is_color_match(current_color, target_color, no_match_threshold):
			is_currently_passable = false
	
	# Apply collision based on passable state
	if is_currently_passable:
		static_body.set_collision_layer_value(3, false)  # Player can pass through
		static_body.set_collision_layer_value(5, true)   # Raycasts can still detect
		light_occluder_2d.occluder = null                # Light passes through
	else:
		static_body.set_collision_layer_value(3, true)   # Player blocked
		static_body.set_collision_layer_value(5, true)   # Raycasts detect barrier
		light_occluder_2d.occluder = original_occluder   # Light blocked

# This method tells the light system whether this barrier should block further ray detection
func should_block_light() -> bool:
	return not is_currently_passable

# Helper function to set common target colors easily in code
func set_target_color_preset(preset: String):
	match preset.to_lower():
		"white":
			target_color = Color.WHITE
		"cyan":
			target_color = Color.CYAN
		"yellow":
			target_color = Color.YELLOW
		"magenta":
			target_color = Color.MAGENTA
		_:
			print("Unknown color preset: ", preset)
			
# Helper function to get color distance for debugging
func get_color_distance_to_target() -> float:
	var current_color = color_rect.color
	return sqrt(
		pow(current_color.r - target_color.r, 2) + 
		pow(current_color.g - target_color.g, 2) + 
		pow(current_color.b - target_color.b, 2)
	)
