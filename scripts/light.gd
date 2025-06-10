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
	
	# Check all raycasts for barrier hits
	for raycast in raycast_array:
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			if collider and collider.is_in_group("walls"):
				# Wall is blocking, don't check for barriers behind it
				continue
			if collider and collider.is_in_group("barriers"):
				var barrier = collider.get_parent()  # Get the barrier node
				if barrier and not barrier in new_hit_barriers:
					new_hit_barriers.append(barrier)
			if collider.is_in_group("lenses"):
				var lens = collider.get_parent()
				lens.handle_light_hit(self, raycast)
				
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

func _exit_tree():
	# Clean up when light is removed from scene
	for barrier in currently_hit_barriers:
		barrier.remove_light(self)
