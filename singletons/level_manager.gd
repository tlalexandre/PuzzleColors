extends Node

# Array of level scene paths in order
var levels: Array[String] = [
	"res://levels/level_1.tscn",
	# Add more levels here as you create them
]

var current_level_index: int = 0

func _ready():
	# DON'T auto-load the first level anymore
	print("Level Manager initialized - waiting for game to start")

func start_game():
	# Call this when the player clicks "Play" in the main menu
	current_level_index = 0
	load_current_level()

func load_current_level():
	if current_level_index >= 0 and current_level_index < levels.size():
		var level_path = levels[current_level_index]
		print("Loading level: ", level_path)
		get_tree().change_scene_to_file(level_path)
	else:
		# All levels completed - go back to main menu
		print("All levels completed! Returning to main menu")
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_level_completed():
	print("Level ", current_level_index + 1, " completed!")
	current_level_index += 1
	
	# Add a small delay before loading next level
	await get_tree().create_timer(1.0).timeout
	load_current_level()

func restart_current_level():
	load_current_level()

func go_to_level(level_index: int):
	if level_index >= 0 and level_index < levels.size():
		current_level_index = level_index
		load_current_level()

func get_current_level_number() -> int:
	return current_level_index + 1

func get_total_levels() -> int:
	return levels.size()
