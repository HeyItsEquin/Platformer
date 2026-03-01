extends Node2D

func Initialize(player: CharacterBody2D, camera: Camera2D) -> void:
	player.position = $PlayerSpawn.position
	camera.load_background("Brain")
