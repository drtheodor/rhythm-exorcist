extends Sprite2D

@export var fall_speed: float = 2.0

var init_x_pos: float = 208.0

var has_passed: bool = false
var pass_threshold = 64

func _init() -> void:
	set_process(false)

func _process(delta: float) -> void:
	position += Vector2(-fall_speed, 0)
	
	if position.x < pass_threshold and not $Timer.is_stopped():
		# print($Timer.wait_time - $Timer.time_left)
		$Timer.stop()
		has_passed = true

func setup(target_y: float, target_frame: int):
	position = Vector2(init_x_pos, target_y)
	frame = target_frame
	
	set_process(true)

func _on_destroy_timer_timeout() -> void:
	queue_free()
