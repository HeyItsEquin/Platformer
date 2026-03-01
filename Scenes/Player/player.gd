extends CharacterBody2D

@export var move_speed = 400.0
@export var burrow_move_speed = 200.0
@export var jump_force_standard = 500
@export var jump_force_burrowed = 700
@export var jump_cut_multiplier = 0.5
@export var fall_gravity_multiplier = 1.8
@export var collision_height_jumping = 32.0
@export var collision_height = 24.0
@export var collision_height_burrowed = 8.0
@export var move_speed_transition_speed = 4.0

@export var level: Node2D

const COLLISION_OFFSET_Y = 4
const GRAVITY = 980

var is_jumping = false
var is_burrowed = false
var is_burrowing = false
var use_burrowed_speed = false
var animation_locked = false

enum JumpState { NONE, TAKEOFF, RISING, APEX, FALLING, LANDING, DROPPING }
var jump_state = JumpState.NONE

var should_move = true
var should_jump = true
var should_burrow = true

const JUMP_APEX_THRESHOLD = 50

const TAKEOFF_FRAMES = 0
const TAKEOFF_FRAMES_BURROWED = 4
const LANDING_FRAMES = 4
const ENTER_BURROW_FRAMES = 4
const DROPPING_FRAMES = 4
var state_timer = 0

var current_move_speed = move_speed
var latest_checkpoint: Vector2

func _ready() -> void:
	assert(level)

func _process(delta: float) -> void:
	update_animation()
	update_collider()

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	process_input(delta)
	move_and_slide()

func set_player_control(enabled: bool) -> void:
	should_move = enabled
	should_jump = enabled
	should_burrow = enabled

func set_burrowed(burrowed: bool) -> void:
	is_burrowed = burrowed
	use_burrowed_speed = burrowed

func reset_state() -> void:
	set_player_control(true)
	set_burrowed(false)
	animation_locked = false
	is_burrowing = false
	jump_state = JumpState.NONE
	velocity = Vector2.ZERO

func apply_gravity(delta: float) -> void:
	if is_on_floor():
		is_jumping = false
		return

	var gravity_this_frame = GRAVITY
	if velocity.y > 0:
		gravity_this_frame *= fall_gravity_multiplier

	velocity.y += gravity_this_frame * delta

func update_animation() -> void:
	if animation_locked:
		return

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
		JumpState.DROPPING:
			state_timer -= 1
			if state_timer <= 0:
				jump_state = JumpState.FALLING
				$PlayerSprite.play("jump_falling")
			if is_on_floor():
				jump_state = JumpState.LANDING
				state_timer = LANDING_FRAMES
				$PlayerSprite.play("jump_landing")
		JumpState.NONE:
			if velocity.y > 0 and not is_on_floor():
				jump_state = JumpState.DROPPING
				state_timer = DROPPING_FRAMES
				$PlayerSprite.play("dropping")

			if velocity.x != 0 and not (is_burrowed or is_burrowing):
				$PlayerSprite.play("moving")
			else:
				if is_burrowed and not is_burrowing:
					$PlayerSprite.play("in_burrow")
				if not is_burrowing and not is_burrowed:
					$PlayerSprite.play("idle")

	if velocity.y > 0 and not is_jumping and jump_state == JumpState.NONE:
		jump_state = JumpState.APEX
		$PlayerSprite.play("jump_falling")

func process_input(delta: float) -> void:
	if Input.is_action_pressed("move_right"):
		move(MoveDir.RIGHT, delta)
	elif Input.is_action_pressed("move_left"):
		move(MoveDir.LEFT, delta)
	else:
		move(MoveDir.NONE, delta)

	if Input.is_action_just_pressed("move_up"):
		jump()

	if Input.is_action_just_released("move_up"):
		jump_cut()

	if Input.is_action_just_pressed("move_up") and is_burrowed:
		exit_burrow(true)

	if Input.is_action_pressed("burrow"):
		enter_burrow()
	else:
		exit_burrow(false)

	if Input.is_action_just_released("debug"):
		debug()

func jump(burrowed: bool = false) -> void:
	if is_on_floor() and should_jump:
		velocity.y = -(jump_force_burrowed if burrowed else jump_force_standard)
		is_jumping = true
		jump_state = JumpState.TAKEOFF
		state_timer = TAKEOFF_FRAMES_BURROWED if burrowed else TAKEOFF_FRAMES
		$PlayerSprite.play("jump_takeoff", 0.6)

func jump_cut() -> void:
	if is_jumping and velocity.y < 0:
		velocity.y *= jump_cut_multiplier

func enter_burrow() -> void:
	if not can_burrow():
		return

	is_burrowing = true
	should_jump = false
	use_burrowed_speed = true
	$PlayerSprite.play("enter_burrow", 1.4)
	await $PlayerSprite.animation_finished
	should_jump = true
	is_burrowing = false
	is_burrowed = true

func can_burrow() -> bool:
	if not should_burrow:
		return false
	if is_burrowed or is_burrowing:
		return false
	if is_jumping:
		return false
	return true

func exit_burrow(jumped: bool) -> void:
	if not can_exit_burrow():
		return

	if jumped:
		set_burrowed(false)
		should_jump = true
		jump(true)
	else:
		is_burrowing = true
		should_jump = false
		use_burrowed_speed = false
		$PlayerSprite.play("exit_burrow", 1.3)
		await $PlayerSprite.animation_finished
		should_jump = true
		set_burrowed(false)
		is_burrowing = false

func can_exit_burrow() -> bool:
	return (is_burrowed and not is_burrowing and should_burrow) and not would_collide_with_size(collision_height)

# Don't ask me how this works, I don't want to think about it
func would_collide_with_size(new_height: float) -> bool:
	var space = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()

	var shape = RectangleShape2D.new()
	shape.size = Vector2(($CollisionShape.shape as RectangleShape2D).size.x, new_height)

	var offset = (collision_height - new_height) / 2.0
	var shape_transform = global_transform
	shape_transform.origin.y += COLLISION_OFFSET_Y + offset

	query.shape = shape
	query.transform = shape_transform
	query.exclude = [self]

	return space.intersect_shape(query).size() > 0

enum MoveDir { RIGHT, LEFT, NONE }
func move(dir: MoveDir, delta: float) -> void:
	if dir == MoveDir.RIGHT:
		velocity.x = get_move_speed(delta)
		$PlayerSprite.flip_h = false
	if dir == MoveDir.LEFT:
		velocity.x = -get_move_speed(delta)
		$PlayerSprite.flip_h = true
	if dir == MoveDir.NONE:
		velocity.x = 0

	if not should_move:
		velocity.x = 0

func get_move_speed(delta: float) -> float:
	var target = burrow_move_speed if use_burrowed_speed else move_speed
	current_move_speed = lerpf(current_move_speed, target, move_speed_transition_speed * delta)
	return current_move_speed

# For the love of god don't fucking change this PLEASE
func update_collider() -> void:
	var target_height = get_target_collider_height()
	var offset = (collision_height - target_height) / 2.0
	($CollisionShape.shape as RectangleShape2D).size.y = target_height
	$CollisionShape.position.y = COLLISION_OFFSET_Y + offset

func get_target_collider_height() -> float:
	var target = collision_height
	if is_burrowed and not is_jumping:
		target = collision_height_burrowed
	if is_jumping and not is_burrowed:
		target = collision_height_jumping
	return target

func die() -> void:
	set_player_control(false)
	animation_locked = true
	$PlayerSprite.stop()
	$PlayerSprite.play("death", 2.4)
	await $PlayerSprite.animation_finished
	respawn(get_latest_checkpoint())

func respawn(location: Vector2 = position) -> void:
	reset_state()
	position = location
	$PlayerSprite.play("idle")

func get_latest_checkpoint() -> Vector2:
	return level.get_node("PlayerSpawn").position

func debug() -> void:
	die()

func _on_player_sprite_animation_finished() -> void:
	pass
