extends Node2D
@export var barrier_color: Color = Color.RED
var active_lights: Dictionary = {}  # source_node -> color
@onready var color_rect: ColorRect = $ColorRect
@onready var static_body: StaticBody2D = $StaticBody2D

func _ready() -> void:
	color_rect.color = barrier_color

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
	
	for light_color in active_lights.values():
		final_color.r = min(final_color.r + light_color.r, 1.0)
		final_color.g = min(final_color.g + light_color.g, 1.0)
		final_color.b = min(final_color.b + light_color.b, 1.0)
	
	color_rect.color = final_color

func update_collision():
	var current_color = color_rect.color
	var is_white = current_color.r >= 0.9 and current_color.g >= 0.9 and current_color.b >= 0.9
	
	if is_white:
		static_body.set_collision_layer_value(4, false)  # Passable
	else:
		static_body.set_collision_layer_value(4, true)   # Solid
		
