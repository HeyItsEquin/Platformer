extends CharacterBody2D

@export var move_speed = 400
@export var jump_force = 500 
@export var jump_cut_multiplier = 0.5 #Multiplier for gravity when a jump is cut off
@export var fall_gravity_multiplier = 1.8 # Gravitational multiplier when falling from a jump

const GRAVITY = 980

var is_jumping = false
var is_burrowed = false
var is_burrowing = false
var DEBUG_ANIM = false

enum JumpState { NONE, TAKEOFF, RISING, APEX, FALLING, LANDING } # Different "stages" of a jump
var jump_state = JumpState.NONE # Current stage of the jump, 'NONE' means not jumping. For use in animations

var should_move = true # Can the player currently move

const JUMP_APEX_THRESHOLD = 50 # The velocity threshold wherein a jump is considered at its 'apex'

const TAKEOFF_FRAMES = 4 # Amount of frames that the takeoff animation will have
const LANDING_FRAMES = 5 # Amount of frames the landing animation will have
var state_timer = 0

func _process(delta: float) -> void:
    update_animation()

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

func update_animation() -> void:
    match jump_state:
        JumpState.TAKEOFF:
            state_timer -= 1
            if state_timer <= 0:
                jump_state = JumpState.RISING
                $PlayerSprite.play("jump_rising")
        JumpState.RISING:
            if velocity.y >= -JUMP_APEX_THRESHOLD:
                jump_state = JumpState.APEX
                $PlayerSprite.play("jump_apex")
        JumpState.APEX:
            if velocity.y > JUMP_APEX_THRESHOLD:
                jump_state = JumpState.FALLING
                $PlayerSprite.play("jump_falling")
        JumpState.FALLING:
            if is_on_floor():
                jump_state = JumpState.LANDING
                state_timer = LANDING_FRAMES
                $PlayerSprite.play("jump_landing")
        JumpState.LANDING:
            state_timer -= 1
            if state_timer <= 0:
                jump_state = JumpState.NONE
        JumpState.NONE:
            if velocity.x != 0:
                $PlayerSprite.play("moving");
            else:
                if is_burrowed:
                    $PlayerSprite.play("in_burrow")
                if not is_burrowing and not is_burrowed:
                    $PlayerSprite.play("idle")

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

    if Input.is_action_just_pressed("burrow"):
        burrow()

func jump() -> void:
    if is_on_floor():
        velocity.y = -jump_force
        is_jumping = true
        jump_state = JumpState.TAKEOFF
        state_timer = TAKEOFF_FRAMES

func jump_cut() -> void:
    if is_jumping and velocity.y < 0:
        velocity.y *= jump_cut_multiplier

func burrow() -> void:
    if is_jumping:
        return
    should_move = false
    is_burrowing = true
    $PlayerSprite.play("enter_burrow")
    await $PlayerSprite.animation_finished
    is_burrowing = false
    is_burrowed = true
    should_move = true
    
func move(dir: MoveDir) -> void:
    if dir == MoveDir.RIGHT and should_move:
        velocity.x = move_speed
        $PlayerSprite.flip_h = false
    if dir == MoveDir.LEFT and should_move:
        velocity.x = -move_speed
        $PlayerSprite.flip_h = true
    if dir == MoveDir.NONE:
        velocity.x = 0

enum MoveDir {
	RIGHT = 0,
	LEFT,
    NONE
}

func _on_player_sprite_animation_finished() -> void:
    pass