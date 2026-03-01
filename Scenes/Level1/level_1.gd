extends Node2D

func Initialize(player: CharacterBody2D) -> void:
	player.position = $PlayerSpawn.position
