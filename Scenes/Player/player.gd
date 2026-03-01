extends CharacterBody2D

@export var move_speed = 400.0
@export var burrow_move_speed = 200.0
@export var burrow_wall_move_speed = 200.0
@export var jump_force_wall = 400.0
@export var jump_force_wall_horizontal = 200.0
@export var jump_force_standard = 500
@export var jump_force_burrowed = 700
@export var jump_cut_multiplier = 0.5
@export var fall_gravity_multiplier = 1.8
@export var collision_height_jumping = 32.0
@export var collision_height = 24.0
@export var collision_height_burrowed = 8.0
@export var move_speed_transition_speed = 4.0

@export var level: Node2D
@export var tilemap: TileMapLayer

const COLLISION_OFFSET_Y = 4
const GRAVITY = 980
const JUMP_APEX_THRESHOLD = 50

const TAKEOFF_FRAMES = 0
const TAKEOFF_FRAMES_BURROWED = 4
const LANDING_FRAMES = 4
const DROPPING_FRAMES = 4
const ENTER_BURROW_FRAMES = 7

enum JumpState { NONE, TAKEOFF, RISING, APEX, FALLING, LANDING, DROPPING }
var jump_state = JumpState.NONE
var state_timer = 0

enum BurrowState { NONE, ENTERING, BURROWED, EXITING, ENTERING_WALL, WALL, EXITING_WALL }
var burrow_state = BurrowState.NONE

var is_jumping = false
var use_burrowed_speed = false
var animation_locked = false
var is_dying = false

var is_burrowed: bool:
	get: return burrow_state == BurrowState.BURROWED
var is_burrowing: bool:
	get: return burrow_state == BurrowState.ENTERING or burrow_state == BurrowState.EXITING or burrow_state == BurrowState.ENTERING_WALL or burrow_state == BurrowState.EXITING_WALL

var should_move = true
var should_jump = true
var should_burrow = true

var wall_direction: int = 0

var current_move_speed = move_speed
var latest_checkpoint: Vector2

func _ready() -> void:
	assert(level)
	latest_checkpoint = level.get_node("PlayerSpawn").position
	tilemap = level.get_node("ForegroundTiles")

func _process(delta: float) -> void:
	update_burrow()
	update_animation()
	update_collider()

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	process_input(delta)
	process_wall_movement(delta)
	if burrow_state != BurrowState.WALL and burrow_state != BurrowState.ENTERING_WALL and burrow_state != BurrowState.EXITING_WALL:
		move_and_slide()
	check_collisions()
	check_wall_burrow()

func set_player_control(enabled: bool) -> void:
	should_move = enabled
	should_jump = enabled
	should_burrow = enabled

func set_burrowed(burrowed: bool) -> void:
	burrow_state = BurrowState.BURROWED if burrowed else BurrowState.NONE
	use_burrowed_speed = burrowed

func reset_state() -> void:
	set_player_control(true)
	set_burrowed(false)
	animation_locked = false
	jump_state = JumpState.NONE
	velocity = Vector2.ZERO

func apply_gravity(delta: float) -> void:
	if is_on_floor():
		is_jumping = false
		return

	if burrow_state == BurrowState.WALL or burrow_state == BurrowState.ENTERING_WALL or burrow_state == BurrowState.EXITING_WALL:
		velocity.y = 0
		return

	var gravity_this_frame = GRAVITY
	if velocity.y > 0:
		gravity_this_frame *= fall_gravity_multiplier

	velocity.y += gravity_this_frame * delta

func update_animation() -> void:
	if animation_locked:
		return

	if is_burrow_anim_playing():
		return

	if burrow_state == BurrowState.WALL:
		$PlayerSprite.play("in_wall")
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
			elif velocity.x != 0 and not (is_burrowed or is_burrowing):
				$PlayerSprite.play("moving")
			elif burrow_state == BurrowState.BURROWED:
				$PlayerSprite.play("in_burrow")
			elif not is_burrowing and not is_burrowed:
				$PlayerSprite.play("idle")

func is_burrow_anim_playing() -> bool:
	return burrow_state == BurrowState.ENTERING or burrow_state == BurrowState.EXITING or burrow_state == BurrowState.ENTERING_WALL or burrow_state == BurrowState.EXITING_WALL

func update_burrow() -> void:
	match burrow_state:
		BurrowState.ENTERING:
			if not is_on_floor():
				set_burrow_state(BurrowState.NONE)
			elif $PlayerSprite.animation == "enter_burrow" and not $PlayerSprite.is_playing():
				set_burrow_state(BurrowState.BURROWED)
		BurrowState.EXITING:
			if $PlayerSprite.animation == "exit_burrow" and not $PlayerSprite.is_playing():
				set_burrow_state(BurrowState.NONE)
		BurrowState.ENTERING_WALL:
			if $PlayerSprite.animation == "enter_wall" and not $PlayerSprite.is_playing():
				set_burrow_state(BurrowState.WALL)
		BurrowState.WALL:
			var check_pos = global_position + Vector2(wall_direction * 32, 0)
			var tile_pos = tilemap.local_to_map(check_pos - tilemap.global_position)
			var tile_data = tilemap.get_cell_tile_data(tile_pos)
			if not tile_data or not tile_data.get_custom_data("burrowable"):
				set_burrow_state(BurrowState.EXITING_WALL)
		BurrowState.EXITING_WALL:
			if $PlayerSprite.animation == "exit_wall" and not $PlayerSprite.is_playing():
				set_burrow_state(BurrowState.NONE)

func set_burrow_state(new: BurrowState) -> void:
	match new:
		BurrowState.NONE:
			use_burrowed_speed = false
			should_jump = true
			$CollisionShape.disabled = false
			if is_on_floor():
				jump_state = JumpState.NONE
		BurrowState.ENTERING:
			should_jump = false
			use_burrowed_speed = true
			$PlayerSprite.play("enter_burrow", 1.4)
		BurrowState.BURROWED:
			should_jump = true
		BurrowState.EXITING:
			use_burrowed_speed = false
			$PlayerSprite.play("exit_burrow", 1.3)
		BurrowState.ENTERING_WALL:
			should_jump = false
			velocity = Vector2.ZERO
			$CollisionShape.disabled = true
			$PlayerSprite.play("enter_wall", 1.4) # Placehodler, add proper anim later
			jump_state = JumpState.NONE
		BurrowState.WALL:
			should_jump = true
			$CollisionShape.disabled = true
			$PlayerSprite.play("in_wall") # Placeholder, add proper anim later
		BurrowState.EXITING_WALL:
			should_jump = false
			$CollisionShape.disabled = false
			$PlayerSprite.play("exit_wall", 1.5) # Placeholder, add proper anim later
	burrow_state = new

func check_wall_burrow() -> void:
	if not Input.is_action_pressed("burrow"):
		return
	if burrow_state != BurrowState.NONE and burrow_state != BurrowState.BURROWED:
		return
	if not should_burrow:
		return

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var normal = collision.get_normal()

		if abs(normal.x) > 0.5:
			var dir = -1 if normal.x > 0 else 1
			
			# Only burrow into wall if player is pressing toward it
			if dir == 1 and not Input.is_action_pressed("move_right"):
				continue
			if dir == -1 and not Input.is_action_pressed("move_left"):
				continue
			
			var check_pos = global_position + Vector2(dir * 32, 0)
			var tile_pos = tilemap.local_to_map(check_pos - tilemap.global_position)
			var tile_data = tilemap.get_cell_tile_data(tile_pos)

			if tile_data and tile_data.get_custom_data("burrowable"):
				wall_direction = dir
				set_burrow_state(BurrowState.ENTERING_WALL)
				return

func process_input(delta: float) -> void:
	if burrow_state == BurrowState.WALL or burrow_state == BurrowState.ENTERING_WALL or burrow_state == BurrowState.EXITING_WALL:
		return

	if Input.is_action_pressed("move_right"):
		move(MoveDir.RIGHT, delta)
	elif Input.is_action_pressed("move_left"):
		move(MoveDir.LEFT, delta)
	else:
		move(MoveDir.NONE, delta)

	if Input.is_action_just_pressed("move_up"):
		if is_burrowed:
			exit_burrow(true)
		elif burrow_state != BurrowState.EXITING:
			jump()

	if Input.is_action_just_released("move_up"):
		jump_cut()

	if Input.is_action_pressed("burrow"):
		enter_burrow()
	else:
		exit_burrow(false)

func process_wall_movement(delta: float) -> void:
	if burrow_state != BurrowState.WALL:
		return

	if Input.is_action_just_released("burrow"):
		velocity = Vector2.ZERO
		set_burrow_state(BurrowState.EXITING_WALL)
		return

	if Input.is_action_just_pressed("wall_jump"):
		velocity = Vector2.ZERO
		$CollisionShape.disabled = false
		burrow_state = BurrowState.NONE
		should_jump = true
		use_burrowed_speed = false
		velocity.x = -wall_direction * jump_force_wall_horizontal
		velocity.y = -jump_force_wall
		is_jumping = true
		jump_state = JumpState.TAKEOFF
		state_timer = TAKEOFF_FRAMES
		return

	if Input.is_action_pressed("move_up"):
		velocity.y = -burrow_wall_move_speed
	elif Input.is_action_pressed("move_down"):
		velocity.y = burrow_wall_move_speed
	else:
		velocity.y = 0

	if velocity.y > 0:
		var next_pos = global_position + Vector2(0, velocity.y * get_physics_process_delta_time())
		var check_pos = next_pos + Vector2(wall_direction * 32, 8)
		var tile_pos = tilemap.local_to_map(check_pos - tilemap.global_position)
		var tile_data = tilemap.get_cell_tile_data(tile_pos)
		if not tile_data or not tile_data.get_custom_data("burrowable"):
			velocity.y = 0

	if velocity.y < 0:
		var check_pos = global_position + Vector2(wall_direction * 32, -collision_height / 2.0)
		var tile_pos = tilemap.local_to_map(check_pos - tilemap.global_position)
		var tile_data = tilemap.get_cell_tile_data(tile_pos)
		if not tile_data or not tile_data.get_custom_data("burrowable"):
			velocity.y = 0

	velocity.x = 0
	position += velocity * delta

func jump(burrowed: bool = false, from_wall: bool = false) -> void:
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
	set_burrow_state(BurrowState.ENTERING)

func can_burrow() -> bool:
	if not should_burrow or burrow_state != BurrowState.NONE or is_jumping or not is_on_floor():
		return false
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var normal = collision.get_normal()
		if abs(normal.x) > 0.5:
			var dir = -1 if normal.x > 0 else 1
			if dir == 1 and Input.is_action_pressed("move_right"):
				var check_pos = global_position + Vector2(dir * 32, 0)
				var tile_pos = tilemap.local_to_map(check_pos - tilemap.global_position)
				var tile_data = tilemap.get_cell_tile_data(tile_pos)
				if tile_data and tile_data.get_custom_data("burrowable"):
					return false
			if dir == -1 and Input.is_action_pressed("move_left"):
				var check_pos = global_position + Vector2(dir * 32, 0)
				var tile_pos = tilemap.local_to_map(check_pos - tilemap.global_position)
				var tile_data = tilemap.get_cell_tile_data(tile_pos)
				if tile_data and tile_data.get_custom_data("burrowable"):
					return false
	
	return true

func exit_burrow(jumped: bool) -> void:
	if burrow_state == BurrowState.ENTERING:
		set_burrow_state(BurrowState.NONE)
		return

	if jumped:
		if burrow_state != BurrowState.BURROWED or not should_burrow:
			return
		if not can_exit_burrow():
			return
		set_burrow_state(BurrowState.NONE)
		should_jump = true
		jump(true)
	else:
		if not can_exit_burrow():
			return
		set_burrow_state(BurrowState.EXITING)

func can_exit_burrow() -> bool:
	return burrow_state == BurrowState.BURROWED and should_burrow and not would_collide_with_size(collision_height)

# Don't ask me how this works, I don't want to think about it
func would_collide_with_size(new_height: float) -> bool:
	var space = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()

	var shape = RectangleShape2D.new()
	shape.size = Vector2(($CollisionShape.shape as RectangleShape2D).size.x, new_height)

	var current_height = ($CollisionShape.shape as RectangleShape2D).size.y
	var offset = (current_height - new_height) / 2.0
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
	elif dir == MoveDir.LEFT:
		velocity.x = -get_move_speed(delta)
		$PlayerSprite.flip_h = true
	else:
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
	if is_burrowed and not is_jumping:
		return collision_height_burrowed
	if is_jumping and not is_burrowed:
		return collision_height_jumping
	return collision_height

func check_collisions() -> void:
	for i in get_slide_collision_count():
		var collider = get_slide_collision(i).get_collider()
		if collider.is_in_group("Checkpoint"):
			latest_checkpoint = collider.position
		if collider.has_method("_on_player_collision"):
			collider._on_player_collision(self)

func die() -> void:
	is_dying = true
	set_player_control(false)
	animation_locked = true
	$PlayerSprite.stop()
	$PlayerSprite.play("death", 2.4)
	await $PlayerSprite.animation_finished
	is_dying = false
	respawn(latest_checkpoint)

func respawn(location: Vector2 = position) -> void:
	reset_state()
	position = location
	$PlayerSprite.play("idle")

func _on_player_sprite_animation_finished() -> void:
	pass
