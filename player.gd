extends CharacterBody2D

@export var move_speed = 400
@export var burrow_move_speed = 200 # Movement speed while burrowed
@export var jump_force = 500 
@export var jump_cut_multiplier = 0.5 #Multiplier for gravity when a jump is cut off
@export var fall_gravity_multiplier = 1.8 # Gravitational multiplier when falling from a jump
@export var collision_height = 24.0 # Hitbox height
@export var collision_height_burrowed = 8.0 # Hitbox height while burrowed

const GRAVITY = 980

var is_jumping = false
var is_burrowed = false
var is_burrowing = false
var DEBUG_ANIM = false

enum JumpState { NONE, TAKEOFF, RISING, APEX, FALLING, LANDING } # Different "stages" of a jump
var jump_state = JumpState.NONE # Current stage of the jump, 'NONE' means not jumping. For use in animations

var should_move = true # Can the player currently move

const JUMP_APEX_THRESHOLD = 50 # The velocity threshold wherein a jump is considered at its 'apex'

const TAKEOFF_FRAMES = 0 # Amount of frames that the takeoff animation has
const LANDING_FRAMES = 2 # Amount of frames the landing animation has
const ENTER_BURROW_FRAMES = 6 # Amount of frames the enter burrow animation has
var state_timer = 0

func _process(delta: float) -> void:
	update_animation()
	update_collider()

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
			if velocity.x != 0 and not (is_burrowed or is_burrowing):
				$PlayerSprite.play("moving")
			else:
				if is_burrowed and not is_burrowing:
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

	if Input.is_action_pressed("burrow"):
		enter_burrow()
	else:
		exit_burrow()

func jump() -> void:
	if is_on_floor():
		velocity.y = -jump_force
		is_jumping = true
		jump_state = JumpState.TAKEOFF
		state_timer = TAKEOFF_FRAMES

func jump_cut() -> void:
	if is_jumping and velocity.y < 0:
		velocity.y *= jump_cut_multiplier

func enter_burrow() -> void:
	if is_jumping or is_burrowed: # Can't burrow while jumping and if already burrowed do nothing
		return

	is_burrowing = true
	$PlayerSprite.play("enter_burrow", 1.4)
	await $PlayerSprite.animation_finished
	is_burrowing = false
	is_burrowed = true
	
func exit_burrow() -> void:
	if not can_exit_burrow():
		return

	is_burrowing = true
	is_burrowed = false
	$PlayerSprite.play("enter_burrow", -1.6, true)
	await get_tree().create_timer($PlayerSprite.sprite_frames.get_animation_speed("enter_burrow") * ENTER_BURROW_FRAMES / 60.0).timeout
	is_burrowing = false
	
func can_exit_burrow() -> bool:
	return is_burrowed

func move(dir: MoveDir) -> void:
	if dir == MoveDir.RIGHT and should_move:
		velocity.x = get_move_speed()
		$PlayerSprite.flip_h = false
	if dir == MoveDir.LEFT and should_move:
		velocity.x = -get_move_speed()
		$PlayerSprite.flip_h = true
	if dir == MoveDir.NONE:
		velocity.x = 0

func get_move_speed() -> int:
	return burrow_move_speed if is_burrowed else move_speed

# For the love of god don't fucking change this PLEASE
func update_collider() -> void:
	var target_height = collision_height if not is_burrowed else collision_height_burrowed
	var offset = (collision_height - target_height) / 2.0
	($CollisionShape.shape as RectangleShape2D).size.y = target_height
	$CollisionShape.position.y = 4 + offset

enum MoveDir {
	RIGHT = 0,
	LEFT,
	NONE
}

func _on_player_sprite_animation_finished() -> void:
	pass
