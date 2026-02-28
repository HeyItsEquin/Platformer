extends CharacterBody2D

@export var move_speed = 400
@export var jump_force = 500
@export var jump_cut_multiplier = 0.5
@export var fall_gravity_multiplier = 1.8

const GRAVITY = 980

var is_jumping = false

func _physics_process(delta: float) -> void:
    apply_gravity(delta)
    process_input()
    move_and_slide()

func apply_gravity(delta: float) -> void:
    if is_on_floor():
        is_jumping = false
        return

    var gravity_this_frame = GRAVITY
    if velocity.y > 0:
        gravity_this_frame *= fall_gravity_multiplier

    velocity.y += gravity_this_frame * delta

func process_input() -> void:
    if Input.is_action_pressed("move_right"):
        move(MoveDir.RIGHT)
    elif Input.is_action_pressed("move_left"):
        move(MoveDir.LEFT)
    else:
        move(MoveDir.NONE)

    if Input.is_action_just_pressed("move_up"):
        jump()

    if Input.is_action_just_released("move_up"):
        jump_cut()

func jump() -> void:
    if is_on_floor():
        velocity.y = -jump_force
        is_jumping = true

func jump_cut() -> void:
    if is_jumping and velocity.y < 0:
        velocity.y *= jump_cut_multiplier

func move(dir: MoveDir) -> void:
    if dir == MoveDir.RIGHT:
        velocity.x = move_speed
    if dir == MoveDir.LEFT:
        velocity.x = -move_speed
    if dir == MoveDir.NONE:
        velocity.x = 0

enum MoveDir {
	RIGHT = 0,
	LEFT,
    NONE
}