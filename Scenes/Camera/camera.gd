extends Camera2D

@export var follow_target: Node2D
@export var follow_speed: float = 8.0
@export var follow_speed_y: float = 6.0
@export var height_offset: float = 8.0

func _ready() -> void:
	assert(follow_target)

func _physics_process(delta: float) -> void:
	position.x = lerp(position.x, follow_target.position.x, follow_speed * delta)
	position.y = lerp(position.y, follow_target.position.y - height_offset, follow_speed_y * delta)

func load_background(bg: String) -> void:
	match bg:
		"Brain":
			$Brain.visible = true