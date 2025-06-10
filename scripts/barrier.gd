extends Node2D
@export var barrier_color: Color = Color.RED
var active_lights: Dictionary = {}  # source_node -> color
@onready var color_rect: ColorRect = $ColorRect
@onready var static_body: StaticBody2D = $StaticBody2D
@onready var light_occluder_2d: LightOccluder2D = $LightOccluder2D
var original_occluder: OccluderPolygon2D

# Hysteresis thresholds
var white_threshold: float = 0.9      # Need 0.9+ in all channels to become white
var non_white_threshold: float = 0.7  # Need to drop below 0.7 in any channel to become non-white
var is_currently_white: bool = false

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

func update_collision():
	var current_color = color_rect.color
	
	# Hysteresis logic
	if not is_currently_white:
		if current_color.r >= white_threshold and current_color.g >= white_threshold and current_color.b >= white_threshold:
			is_currently_white = true
	else:
		if current_color.r < non_white_threshold or current_color.g < non_white_threshold or current_color.b < non_white_threshold:
			is_currently_white = false
	
	# Apply collision based on white state
	if is_currently_white:
		static_body.set_collision_layer_value(3, false)  # Player can pass through
		# Keep collision layer 5 active so raycasts can still detect this barrier
		static_body.set_collision_layer_value(5, true)   
		light_occluder_2d.occluder = null                # Light passes through
	else:
		static_body.set_collision_layer_value(3, true)   # Player blocked
		static_body.set_collision_layer_value(5, true)   # Raycasts detect barrier
		light_occluder_2d.occluder = original_occluder   # Light blocked

# This method tells the light system whether this barrier should block further ray detection
func should_block_light() -> bool:
	return not is_currently_white
