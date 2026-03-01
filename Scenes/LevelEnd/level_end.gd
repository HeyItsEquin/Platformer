extends "res://Scenes/Obstacle/obstacle.gd"

@export var next_level: Game.Levels

func _ready() -> void:
	assert(next_level)

func _on_player_collision(_player: CharacterBody2D) -> void:
	Game.load_level(next_level)
