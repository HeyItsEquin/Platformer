class_name PlayerAnimator

var player_sprite: AnimatedSprite2D
var player_char: CharacterBody2D

signal burrow_state_changed(old_state: BurrowState, new_state: BurrowState)

enum JumpState { NONE, TAKEOFF, RISING, APEX, FALLING, LANDING, DROPPING }
var jump_state = JumpState.NONE
var state_timer = 0

enum BurrowState { NONE, ENTERING, BURROWED, EXITING, ENTERING_WALL, WALL, EXITING_WALL }
var burrow_state = BurrowState.NONE

var animation_locked = false

const TAKEOFF_FRAMES = 0
const TAKEOFF_FRAMES_BURROWED = 4
const LANDING_FRAMES = 4
const DROPPING_FRAMES = 4

const TRANSITION_ANIMATIONS = {
	BurrowState.ENTERING:      "enter_burrow",
	BurrowState.EXITING:        "exit_burrow",
	BurrowState.ENTERING_WALL:   "enter_wall",
	BurrowState.EXITING_WALL:     "exit_wall",
}

const ANIMATION_SPEEDS = {
	"jump_takeoff": 0.6,
	"enter_burrow": 1.4,
	"exit_burrow":  1.3,
	"enter_wall":   1.4,
	"exit_wall":    1.5,
}

func _init(psprite: AnimatedSprite2D, pchar: CharacterBody2D) -> void:
	player_sprite = psprite
	player_char = pchar

func update_animation() -> void:
	update_jump_state()
	var anim: String = resolve_animation()
	var speed: float = ANIMATION_SPEEDS.get(anim, 1.0)
	if player_sprite.animation != anim:
		player_sprite.play(anim, speed)
	elif not is_transitioning() and not player_sprite.is_playing():
		player_sprite.play(anim, speed)

func update_burrow() -> void:
	print("burrow_state: ", burrow_state, " anim: ", player_sprite.animation, " playing: ", player_sprite.is_playing())
	match burrow_state:
		BurrowState.ENTERING:
			if not player_char.is_on_floor():
				set_burrow_state(BurrowState.NONE)
			elif player_sprite.animation == "enter_burrow" and not player_sprite.is_playing():
				set_burrow_state(BurrowState.BURROWED)
		BurrowState.EXITING:
			if player_sprite.animation == "exit_burrow" and not player_sprite.is_playing():
				set_burrow_state(BurrowState.NONE)
		BurrowState.ENTERING_WALL:
			if player_sprite.animation == "enter_wall" and not player_sprite.is_playing():
				set_burrow_state(BurrowState.WALL)
		BurrowState.WALL:
			if not player_char.is_burrowable_tile():
				set_burrow_state(BurrowState.EXITING_WALL)
		BurrowState.EXITING_WALL:
			if player_sprite.animation == "exit_wall" and not player_sprite.is_playing():
				set_burrow_state(BurrowState.NONE)

func update_jump_state() -> void:
	match jump_state:
		JumpState.TAKEOFF:
			state_timer -= 1
			if state_timer <= 0:
				jump_state = JumpState.RISING
		JumpState.RISING:
			if player_char.velocity.y >= -player_char.JUMP_APEX_THRESHOLD:
				jump_state = JumpState.APEX
		JumpState.APEX:
			if player_char.velocity.y > player_char.JUMP_APEX_THRESHOLD:
				jump_state = JumpState.FALLING
		JumpState.FALLING:
			if player_char.is_on_floor():
				jump_state = JumpState.LANDING
				state_timer = LANDING_FRAMES
		JumpState.LANDING:
			state_timer -= 1
			if state_timer <= 0:
				jump_state = JumpState.NONE
		JumpState.DROPPING:
			state_timer -= 1
			if player_char.is_on_floor():
				jump_state = JumpState.LANDING
				state_timer = LANDING_FRAMES
			elif state_timer <= 0:
				jump_state = JumpState.FALLING
		JumpState.NONE:
			if player_char.velocity.y > 0 and not player_char.is_on_floor():
				jump_state = JumpState.DROPPING
				state_timer = DROPPING_FRAMES

func resolve_animation() -> String:
	if animation_locked:
		return player_sprite.animation

	if on_wall():
		return "in_wall"

	if burrow_state in TRANSITION_ANIMATIONS:
		return TRANSITION_ANIMATIONS[burrow_state]

	match jump_state:
		JumpState.TAKEOFF:  return "jump_takeoff"
		JumpState.RISING:   return "jump_rising"
		JumpState.APEX:     return "jump_apex"
		JumpState.FALLING:  return "jump_falling"
		JumpState.LANDING:  return "jump_landing"
		JumpState.DROPPING: return "dropping"

	if burrow_state == BurrowState.BURROWED:
		return "in_burrow"
	if player_char.velocity.x != 0:
		return "moving"
	return "idle"

func set_burrow_state(new: BurrowState) -> void:
	var old: BurrowState = burrow_state
	burrow_state = new
	burrow_state_changed.emit(old, new)

func takeoff() -> void:
	jump_state = JumpState.TAKEOFF
	state_timer = TAKEOFF_FRAMES_BURROWED if is_burrowed() else TAKEOFF_FRAMES

func is_burrowed() -> bool:
	return burrow_state == BurrowState.BURROWED

func is_transitioning() -> bool:
	return burrow_state in TRANSITION_ANIMATIONS

func is_wall_transitioning() -> bool:
	return burrow_state == BurrowState.ENTERING_WALL or burrow_state == BurrowState.EXITING_WALL

func on_wall() -> bool:
	return burrow_state == BurrowState.WALL
