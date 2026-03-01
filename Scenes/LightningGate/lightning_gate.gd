extends "res://Scenes/Obstacle/obstacle.gd"

func _ready() -> void:
	$ObstacleSprite.play("default")

func _process(_delta: float) -> void:
	pass

func _on_player_collision(player: CharacterBody2D) -> void:
	if not player.is_dying:
		player.die()
