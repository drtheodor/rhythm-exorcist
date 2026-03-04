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

	# For some reason, sometimes, current_key may already be freed but is still in the queue.
	#  This is why we check if its even real. TODO: find out whether this could cause additional issues.
	if not current_key or current_key.has_passed:
		key_running_queue.pop_front()
		Signals.IncrementFear.emit(5)
		current_key.queue_free()
		return

	if Input.is_action_just_pressed(key_name):
		var distance = abs(current_key.pass_threshold - current_key.position.x)
		# $AnimationPlayer.play("hand_shaking")
		var tween = create_tween()
		tween.tween_property(self, "offset:y", -3, 0.1).as_relative().set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "offset:y", 3, 0.1).as_relative().set_trans(Tween.TRANS_SINE)
		
		if distance <= hit_threshold:
			if distance <= perfect_threshold:
				Signals.IncrementFear.emit(-1)
			key_running_queue.pop_front()
			$AnimationPlayer.play("hand_hitting")
			current_key.queue_free()

func create_running_key():
	var kr_inst = key_running.instantiate()
	get_tree().get_root().call_deferred("add_child", kr_inst)
	kr_inst.setup(position.y)
	
	key_running_queue.push_back(kr_inst)

func _on_random_spawn_timer_timeout() -> void:
	self.create_running_key()
	
	$RandomSpawnTimer.wait_time = randf_range(0.4, 3)
	$RandomSpawnTimer.start()
