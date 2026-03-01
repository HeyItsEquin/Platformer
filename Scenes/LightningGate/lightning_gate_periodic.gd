extends "res://Scenes/LightningGate/lightning_gate.gd"

@export var toggle_delay = 2.5
var active = true

func _ready() -> void:
	super._ready()
	var timer = Timer.new()
	timer.wait_time = toggle_delay
	timer.autostart = true
	timer.timeout.connect(toggle_active)
	add_child(timer)

func toggle_active() -> void:
	active = !active
	$CollisionShape.disabled = !active
	$ObstacleSprite.visible = active
