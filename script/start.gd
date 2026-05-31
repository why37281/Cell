extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SettingsIO.load_file()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_exit_pressed() -> void:
	# save()
	get_tree().quit()



func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/game.tscn")


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/settings.tscn")
