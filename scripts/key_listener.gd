extends Sprite2D

const KEY = preload("res://scenes/objects/key_running.tscn")
@export var key_name: String = ""

var key_running_queue = []
var current_key

@export var hit_threshold: float = 16.0 
@export var perfect_threshold: float = 6.0

@export var fear: int = 5
@export var perfect_heal: int = 1

func _process(_delta: float) -> void:
	if current_key and current_key.has_passed:
		self._pick_key()
		GameManager.fear += self.fear
		return

	if Input.is_action_just_pressed(key_name):
		var tween = self.create_tween()
		
		tween.tween_property(self, "offset:y", -3, 0.1).set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "offset:y", 0, 0.1).set_trans(Tween.TRANS_SINE)
		
		if current_key:
			var distance = abs(current_key.pass_threshold - current_key.position.x)
			
			if distance <= hit_threshold:
				if distance <= perfect_threshold:
					GameManager.fear -= self.perfect_heal
				
				self._pick_key();
				$AnimationPlayer.play("hand_hitting")

func _create_key():
	var kr_inst = KEY.instantiate()
	self.get_tree().get_root().add_child(kr_inst)
	
	kr_inst.setup(position.y)
	key_running_queue.append(kr_inst)

func _pick_key():
	if self.current_key:
		self.current_key.queue_free()
	
	self.current_key = key_running_queue.pop_front()

func _on_random_spawn_timer_timeout() -> void:
	self._create_key()
	
	if not current_key:
		self._pick_key()
	
	$RandomSpawnTimer.wait_time = randf_range(0.4, 3)
	$RandomSpawnTimer.start()
