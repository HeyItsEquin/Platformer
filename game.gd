extends Node2D

const CAMERA_SCENE_OBJ: PackedScene = preload("res://Scenes/Camera/Camera.tscn")
const PLAYER_SCENE_OBJ: PackedScene = preload("res://Scenes/Player/player.tscn")
const SCENE_SHELL: PackedScene = preload("res://Scenes/Level1/Level1.tscn")
const SCENE_PSYCH: PackedScene = preload("res://Scenes/Level2/Level2.tscn")
const SCENE_CORE: PackedScene = preload("res://Scenes/Level3/Level3.tscn")

func _ready() -> void:
	# load_level(Levels.SHELL)
	pass

enum Levels { SHELL, PSYCH, CORE }
func load_level(lvl: Levels) -> void:
	match lvl:
		Levels.SHELL:
			load_level_scenes(SCENE_SHELL, "BRAIN")
		Levels.PSYCH:
			load_level_scenes(SCENE_PSYCH, "UNK")
		Levels.CORE:
			load_level_scenes(SCENE_CORE, "UNK")

func load_level_scenes(scene: PackedScene, bg: String) -> void:
	var level = scene.instantiate()
	var player = PLAYER_SCENE_OBJ.instantiate()
	var camera = CAMERA_SCENE_OBJ.instantiate()

	camera.follow_target = player
	match bg:
		"BRAIN":
			camera.current_background = camera.Background.BRAIN
	player.level = level

	add_child(player)
	add_child(camera)
	add_child(level)

	level.Initialize(player)
