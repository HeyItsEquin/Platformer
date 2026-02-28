extends Node2D

var sprite

var moveSpeed = 8

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	sprite = get_node("PlayerSprite")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_pressed("move_right"):
		position.x += moveSpeed
	if Input.is_action_pressed("move_left"):
		position.x -= moveSpeed