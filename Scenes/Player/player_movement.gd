class_name MovementManager

@export var move_speed = 400.0
@export var burrow_move_speed = 200.0
@export var burrow_wall_move_speed = 200.0
@export var jump_force_wall = 400.0
@export var jump_force_wall_horizontal = 400.0
@export var jump_force_standard = 500
@export var jump_force_burrowed = 700
@export var jump_cut_multiplier = 0.5
@export var fall_gravity_multiplier = 1.8
@export var collision_height_jumping = 32.0
@export var collision_height = 24.0
@export var collision_height_burrowed = 8.0
@export var move_speed_transition_speed = 4.0

var player: Player

func _init(player_char: Player) -> void:
	player = player_char
