extends Sprite2D

@export var key_name: String = ""

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(key_name):
		var tween = self.create_tween()
		
		tween.tween_property(self, "offset:y", -3, 0.1).set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "offset:y", 0, 0.1).set_trans(Tween.TRANS_SINE)
		
		$AnimationPlayer.play("hand_hitting")
