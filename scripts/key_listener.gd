extends Sprite2D

@export var manager: MidiManager
@export var key_name: String = ""
@export var y_offset: float = -3.
@export var hit_scale: float = 1.2

@onready var _original_scale = self.scale.x
var is_shaking: bool = false

func shake() -> void:
	is_shaking = true
	var tween = create_tween()
	tween.tween_property(self, "offset:y", -2.0, 0.04)
	tween.tween_property(self, "offset:y", 2.0, 0.04)
	tween.tween_property(self, "offset:y", -1.0, 0.04)
	tween.tween_property(self, "offset:y", 0.0, 0.04)
	tween.finished.connect(func(): is_shaking = false)

func _process(_delta: float) -> void:
	if is_shaking:
		return

	if self.manager.key_state.get(key_name) == MidiManager.PRESSED:
		self.create_tween().tween_property(self, "offset:y", y_offset, 0.1).set_trans(Tween.TRANS_SINE)
		self.create_tween().tween_property(self, "scale:x", hit_scale, 0.1).set_trans(Tween.TRANS_SINE)
		self.create_tween().tween_property(self, "scale:y", hit_scale, 0.1).set_trans(Tween.TRANS_SINE)

	if self.manager.key_state.get(key_name) == MidiManager.RELEASED:
		self.create_tween().tween_property(self, "offset:y", 0, 0.1).set_trans(Tween.TRANS_SINE)
		self.create_tween().tween_property(self, "scale:x", _original_scale, 0.1).set_trans(Tween.TRANS_SINE)
		self.create_tween().tween_property(self, "scale:y", _original_scale, 0.1).set_trans(Tween.TRANS_SINE)
