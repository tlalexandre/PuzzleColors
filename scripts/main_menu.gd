extends Control

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var level_select_button: Button = $CenterContainer/VBoxContainer/LevelSelectButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _on_play_button_pressed():
	# Use LevelManager to start the game properly
	LevelManager.start_game()

func _on_level_select_button_pressed():
	print("Level select not implemented yet")
	LevelManager.start_game()

func _on_quit_button_pressed():
	get_tree().quit()
