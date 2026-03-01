extends Camera2D

@export var follow_target: Node2D

func _ready() -> void:
	assert(follow_target)

func _process(delta: float) -> void:
	position.x = follow_target.position.x
	position.y = follow_target.position.y
