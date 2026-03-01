extends Camera2D

@export var follow_target: Node2D
@export var follow_speed: float = 8.0

func _ready() -> void:
	assert(follow_target)

func _physics_process(delta: float) -> void:
	position.x = lerp(position.x, follow_target.position.x, follow_speed * delta)
	position.y = lerp(position.y, follow_target.position.y, follow_speed * delta)