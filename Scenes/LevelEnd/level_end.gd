extends "res://Scenes/Obstacle/obstacle.gd"

@export var next_level: Game.Levels

func _ready() -> void:
	pass

func _on_player_collision(_player: CharacterBody2D) -> void:
	get_tree().change_scene_to_file("res://Scenes/GameEndScreen/GameEndScreen.tscn")
