extends Sprite2D

@onready var key_running = preload("res://scenes/objects/key_running.tscn")
@export var key_name: String = ""

var key_running_queue = []

@export var hit_threshold: float = 16.0 
@export var perfect_threshold: float = 6.0

func _process(_delta: float) -> void:
	if key_running_queue.is_empty():
		return

	var current_key = key_running_queue.front()

	if current_key.has_passed:
		key_running_queue.pop_front()
		Signals.IncrementFear.emit(5)
		current_key.queue_free()
		return

	if Input.is_action_just_pressed(key_name):
		var distance = abs(current_key.pass_threshold - current_key.position.x)
		$AnimationPlayer.play("hand_shaking")
		
		if distance <= hit_threshold:
			if distance <= perfect_threshold:
				Signals.IncrementFear.emit(-1)
			
			key_running_queue.pop_front()
			current_key.queue_free()

func create_running_key():
	var kr_inst = key_running.instantiate()
	get_tree().get_root().call_deferred("add_child", kr_inst)
	kr_inst.setup(position.y, frame + 4)
	
	key_running_queue.push_back(kr_inst)

func _on_random_spawn_timer_timeout() -> void:
	self.create_running_key()
	
	$RandomSpawnTimer.wait_time = randf_range(0.4, 3)
	$RandomSpawnTimer.start()
