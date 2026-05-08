extends Node

func _ready() -> void:
	SaveManager.load_game()
	get_tree().change_scene_to_file.call_deferred("res://scenes/map/world_map.tscn")
