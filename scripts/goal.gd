extends Area2D

signal level_completed
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready():
	# Connect to the level manager if it exists
		level_completed.connect(LevelManager._on_level_completed)

func _on_body_entered(body):
		# Add some visual/audio feedback here if desired
	print("Level completed!")
	animation_player.play("win")
	level_completed.emit()
	
	# Optional: Add a small delay or animation before transitioning
	await get_tree().create_timer(2).timeout
		
		# The actual level transition is handled by LevelManager
