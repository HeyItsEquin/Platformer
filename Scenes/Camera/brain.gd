extends Sprite2D

func _ready() -> void:
	update_size()
	get_viewport().size_changed.connect(update_size)

func update_size() -> void:
	var size = get_viewport_rect().size
	(texture as GradientTexture2D).width = size.x
	(texture as GradientTexture2D).height = size.y
