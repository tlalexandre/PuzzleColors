extends Node2D

@onready var player_light: Node2D = $GameplayLayer/Player/Area2dLight


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
		# In your level or test scene
	var light = player_light
	light.set_debug_occlusion(true)  # Shows green lines to lit objects, red to blocked ones


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
