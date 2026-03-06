class_name PlayerAnimator

var player_sprite: AnimatedSprite2D
var player_char: CharacterBody2D

enum JumpState { NONE, TAKEOFF, RISING, APEX, FALLING, LANDING, DROPPING }
var jump_state = JumpState.NONE
var state_timer = 0

const JUMP_APEX_THRESHOLD = 50

enum BurrowState { NONE, ENTERING, BURROWED, EXITING, ENTERING_WALL, WALL, EXITING_WALL }
var burrow_state = BurrowState.NONE

var animation_locked = false

const TAKEOFF_FRAMES = 0
const TAKEOFF_FRAMES_BURROWED = 4
const LANDING_FRAMES = 4
const DROPPING_FRAMES = 4
const ENTER_BURROW_FRAMES = 7

func _init(psprite: AnimatedSprite2D, pchar: CharacterBody2D) -> void:
	player_sprite = psprite
	player_char = pchar

func update_animation() -> void:
	if animation_locked:
		return # Do not play any animations (for anim priority, will make better later)

	if is_burrow_anim_playing():
		return # Fix later, want burrow anim logic to live here as well
	
	if burrow_state == BurrowState.WALL:
		player_sprite.play("in_wall")
		return


	match jump_state:
		JumpState.TAKEOFF:
			state_timer -= 1
			if state_timer <= 0:
				jump_state = JumpState.RISING
				player_sprite.play("jump_rising")
		JumpState.RISING:
			if player_char.velocity.y >= -JUMP_APEX_THRESHOLD:
				jump_state = JumpState.APEX
				player_sprite.play("jump_apex")
		JumpState.APEX:
			if player_char.velocity.y > JUMP_APEX_THRESHOLD:
				jump_state = JumpState.FALLING
				player_sprite.play("jump_falling")
		JumpState.FALLING:
			if player_char.is_on_floor():
				jump_state = JumpState.LANDING
				state_timer = LANDING_FRAMES
				player_sprite.play("jump_landing")
		JumpState.LANDING:
			state_timer -= 1
			if state_timer <= 0:
				jump_state = JumpState.NONE
		JumpState.DROPPING:
			state_timer -= 1
			if state_timer <= 0:
				jump_state = JumpState.FALLING
				player_sprite.play("jump_falling")
			if player_char.is_on_floor():
				jump_state = JumpState.LANDING
				state_timer = LANDING_FRAMES
				player_sprite.play("jump_landing")
		JumpState.NONE:
			if player_char.velocity.y > 0 and not player_char.is_on_floor():
				jump_state = JumpState.DROPPING
				state_timer = DROPPING_FRAMES
				player_sprite.play("dropping")
			elif player_char.velocity.x != 0 and not (is_burrowed() or is_burrowing()):
				player_sprite.play("moving")
			elif burrow_state == BurrowState.BURROWED:
				player_sprite.play("in_burrow")
			elif not is_burrowing and not is_burrowed:
				player_sprite.play("idle")
	
func is_burrow_anim_playing() -> bool:
	return false

func is_burrowed() -> bool:
	return burrow_state == BurrowState.BURROWED

func is_burrowing() -> bool:
	return burrow_state == BurrowState.ENTERING or burrow_state == BurrowState.EXITING or burrow_state == BurrowState.ENTERING_WALL or burrow_state == BurrowState.EXITING_WALL
