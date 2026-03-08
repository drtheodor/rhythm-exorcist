extends Sprite2D

@export var fall_speed: float = 2.0

var init_x_pos: float = 208.0

var has_passed: bool = false
var pass_threshold = 64

func _init() -> void:
	set_process(false)

func _process(delta: float) -> void:
	position += Vector2(-fall_speed, 0)
	
	# FIXME: does this even need a Timer?
	if position.x < pass_threshold:
		has_passed = true

func setup(target_y: float):
	position = Vector2(init_x_pos, target_y)
	
	set_process(true)
