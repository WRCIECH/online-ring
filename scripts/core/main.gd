extends Node

func _ready() -> void:
	# Title screen handles save loading; go there first on every launch.
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/title_screen.tscn")
