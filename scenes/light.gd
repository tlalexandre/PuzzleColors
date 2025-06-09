extends Node2D
@export var color_light: Color
@export var light_name: String = "Light"  # Give each light a unique name
@onready var torch_light: PointLight2D = $TorchLight
@onready var raycasts: Node2D = $Raycasts
var raycast_array: Array = []
var debug_counter: int = 0

func _ready() -> void:
	torch_light.color = color_light
	
	for child in raycasts.get_children():
		if child is RayCast2D:
			raycast_array.append(child)

func _physics_process(delta: float) -> void:
	for i in range(raycast_array.size()):
		var raycast = raycast_array[i]
		
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			var hit_point = raycast.get_collision_point()
			if collider.is_in_group("barriers"):
				print("Hit barrier with raycast number " + str(i))
