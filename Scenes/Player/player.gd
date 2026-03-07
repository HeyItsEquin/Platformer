extends CharacterBody2D
class_name Player

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

@export var level: Node2D
@export var tilemap: TileMapLayer
@export var background_music: AudioStreamPlayer
@export var jump_sound: AudioStreamPlayer

const COLLISION_OFFSET_Y = 4
const GRAVITY = 980
const JUMP_APEX_THRESHOLD = 50

var is_jumping = false
var use_burrowed_speed = false
var is_dying = false

var wants_to_exit_burrow = false

var should_move = true
var should_jump = true
var should_burrow = true

var wall_direction: int = 0

var current_move_speed = move_speed
var latest_checkpoint: Vector2

var Animator: PlayerAnimator
var Movement: MovementManager

func _ready() -> void:
	assert(level)
	assert(background_music)
	assert(jump_sound)
	latest_checkpoint = level.get_node("PlayerSpawn").position
	tilemap = level.get_node("ForegroundTiles")
	Animator = PlayerAnimator.new($PlayerSprite, self)
	Animator.burrow_state_changed.connect(_on_burrow_state_changed)
	Movement = MovementManager.new(self)

	# background_music.play()

func _process(_delta: float) -> void:
	Animator.update_animation()
	Animator.update_burrow()
	update_collider()

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	process_input(delta)
	process_wall_movement(delta)
	if not Animator.on_wall() and not Animator.is_wall_transitioning():
		move_and_slide()
	check_collisions()
	check_wall_burrow()
	if wants_to_exit_burrow and Animator.is_burrowed() and can_exit_burrow():
		wants_to_exit_burrow = false
		Animator.set_burrow_state(PlayerAnimator.BurrowState.EXITING)

func set_player_control(enabled: bool) -> void:
	should_move = enabled
	should_jump = enabled
	should_burrow = enabled

func set_burrowed(burrowed: bool) -> void:
	Animator.burrow_state = PlayerAnimator.BurrowState.BURROWED if burrowed else PlayerAnimator.BurrowState.NONE
	use_burrowed_speed = burrowed

func reset_state() -> void:
	set_player_control(true)
	set_burrowed(false)
	Animator.animation_locked = false
	Animator.jump_state = Animator.JumpState.NONE
	velocity = Vector2.ZERO

func apply_gravity(delta: float) -> void:
	if is_on_floor():
		is_jumping = false
		return

	if Animator.on_wall():
		velocity.y = 0
		return

	var gravity_this_frame = GRAVITY
	if velocity.y > 0:
		gravity_this_frame *= fall_gravity_multiplier

	velocity.y += gravity_this_frame * delta

func is_burrowable_tile() -> bool:
	var check_pos = global_position + Vector2(wall_direction * 32, 0)
	var tile_pos = tilemap.local_to_map(check_pos - tilemap.global_position)
	var tile_data = tilemap.get_cell_tile_data(tile_pos)
	return tile_data and tile_data.get_custom_data("burrowable")

func check_wall_burrow() -> void:
	if not Input.is_action_pressed("burrow"):
		return
	if Animator.burrow_state != PlayerAnimator.BurrowState.NONE and Animator.burrow_state != PlayerAnimator.BurrowState.BURROWED:
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
				Animator.set_burrow_state(PlayerAnimator.BurrowState.ENTERING_WALL)
				return

func process_input(delta: float) -> void:
	if Animator.on_wall():
		return

	if Input.is_action_pressed("move_right"):
		move(MoveDir.RIGHT, delta)
	elif Input.is_action_pressed("move_left"):
		move(MoveDir.LEFT, delta)
	else:
		move(MoveDir.NONE, delta)

	if Input.is_action_just_pressed("move_up"):
		if Animator.is_burrowed():
			exit_burrow(true)
		elif Animator.burrow_state != PlayerAnimator.BurrowState.EXITING:
			jump()

	if Input.is_action_just_released("move_up"):
		jump_cut()

	if Input.is_action_pressed("burrow"):
		enter_burrow()
		wants_to_exit_burrow = false
	elif Input.is_action_just_released("burrow"):
		wants_to_exit_burrow = true

func process_wall_movement(delta: float) -> void:
	if Animator.burrow_state != PlayerAnimator.BurrowState.WALL:
		return

	if Input.is_action_just_released("burrow"):
		velocity = Vector2.ZERO
		Animator.set_burrow_state(PlayerAnimator.BurrowState.EXITING_WALL)
		return

	if Input.is_action_just_pressed("wall_jump"):
		velocity = Vector2.ZERO
		$CollisionShape.disabled = false
		Animator.burrow_state = PlayerAnimator.BurrowState.NONE
		should_jump = true
		use_burrowed_speed = false
		velocity.x = -wall_direction * jump_force_wall_horizontal
		velocity.y = -jump_force_wall
		is_jumping = true
		Animator.jump_state = PlayerAnimator.JumpState.TAKEOFF
		Animator.state_timer = PlayerAnimator.TAKEOFF_FRAMES
		jump_sound.play()
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
		Animator.takeoff()
		jump_sound.play()

func jump_cut() -> void:
	if is_jumping and velocity.y < 0:
		velocity.y *= jump_cut_multiplier

func enter_burrow() -> void:
	if not can_burrow():
		return
	Animator.set_burrow_state(PlayerAnimator.BurrowState.ENTERING)

func can_burrow() -> bool:
	if not should_burrow or Animator.burrow_state != PlayerAnimator.BurrowState.NONE or is_jumping or not is_on_floor():
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
	if jumped:
		if Animator.burrow_state != PlayerAnimator.BurrowState.BURROWED or not should_burrow:
			return
		if not can_exit_burrow():
			return
		wants_to_exit_burrow = false
		is_jumping = true
		Animator.takeoff()
		Animator.set_burrow_state(PlayerAnimator.BurrowState.NONE)
		should_jump = true
		velocity.y = -jump_force_burrowed
		jump_sound.play()
	else:
		wants_to_exit_burrow = true

func can_exit_burrow() -> bool:
	return Animator.burrow_state == PlayerAnimator.BurrowState.BURROWED and should_burrow and not would_collide_with_size(collision_height)

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
	if Animator.is_burrowed() and not is_jumping:
		return collision_height_burrowed
	if is_jumping and not Animator.is_burrowed():
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
	Animator.animation_locked = true
	$PlayerSprite.stop()
	$PlayerSprite.play("death", 2.4)
	await $PlayerSprite.animation_finished
	is_dying = false
	respawn(latest_checkpoint)

func respawn(location: Vector2 = position) -> void:
	reset_state()
	position = location
	$PlayerSprite.play("idle")

func enable_collider(should: bool) -> void:
	$CollisionShape.disabled = not should

func _on_player_sprite_animation_finished() -> void:
	pass

func _on_burrow_state_changed(old: PlayerAnimator.BurrowState, new: PlayerAnimator.BurrowState) -> void:
	match new:
		PlayerAnimator.BurrowState.NONE:
			use_burrowed_speed = false
			should_jump = true
			enable_collider(true)
			if is_on_floor() and not is_jumping:
				Animator.jump_state = PlayerAnimator.JumpState.NONE
		PlayerAnimator.BurrowState.ENTERING:
			should_jump = false
			use_burrowed_speed = true
		PlayerAnimator.BurrowState.BURROWED:
			should_jump = true
		PlayerAnimator.BurrowState.EXITING:
			use_burrowed_speed = false
		PlayerAnimator.BurrowState.ENTERING_WALL:
			should_jump = false
			velocity = Vector2.ZERO
			enable_collider(false)
			Animator.jump_state = PlayerAnimator.JumpState.NONE
		PlayerAnimator.BurrowState.WALL:
			should_jump = true
			enable_collider(false)
		PlayerAnimator.BurrowState.EXITING_WALL:
			should_jump = false
			enable_collider(true)
