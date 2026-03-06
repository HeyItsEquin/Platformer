extends "res://Scenes/Obstacle/obstacle.gd"

@export var next_level: Game.Levels

func _ready() -> void:
	pass

func _on_player_collision(_player: CharacterBody2D) -> void:
	if not is_inside_tree():
		print("This shit is fuckin me up mane, y u aint in the scene tree :(")
		return
	get_tree().change_scene_to_file("res://Scenes/GameEndScreen/GameEndScreen.tscn")
