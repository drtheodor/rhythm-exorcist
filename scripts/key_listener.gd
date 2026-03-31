extends Sprite2D

@export var manager: MidiManager
@export var key_name: String = ""
@export var y_offset: float = -3.
@export var hit_scale: float = 1.2

@onready var _original_scale = self.scale.x

var key: int

func _ready() -> void:
	self.key = self.manager.keys.find(self.key_name)
	
	if self.key == -1:
		push_warning("Key '", self.key_name, "' is not recognized by the MIDI Manager")
		self.set_process(false)

func hit() -> void:
	var tween: Tween = self.create_tween()
	tween.tween_property(self, "offset:y", y_offset, 0.05).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale:x", hit_scale, 0.05).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale:y", hit_scale, 0.05).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_property(self, "offset:y", 0.0, 0.05).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale:x", _original_scale, 0.05).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale:y", _original_scale, 0.05).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): self.set_process(true))

func shake() -> void:
	self.set_process(false)
	
	var tween: Tween = self.create_tween()
	tween.tween_property(self, "offset:y", -2.0, 0.04)
	tween.tween_property(self, "offset:y", 2.0, 0.04)
	tween.tween_property(self, "offset:y", -1.0, 0.04)
	tween.tween_property(self, "offset:y", 0.0, 0.04)
	tween.tween_callback(func(): self.set_process(true))

func _process(_delta: float) -> void:
	var state: int = self.manager.key_state[self.key]
	if state == MidiManager.PRESSED:
		var tween: Tween = self.create_tween()
		tween.tween_property(self, "offset:y", y_offset, 0.1).set_trans(Tween.TRANS_SINE)
		tween.chain().tween_property(self, "scale:x", hit_scale, 0.1).set_trans(Tween.TRANS_SINE)
		tween.chain().tween_property(self, "scale:y", hit_scale, 0.1).set_trans(Tween.TRANS_SINE)
	elif state == MidiManager.RELEASED:
		var tween: Tween = self.create_tween()
		tween.tween_property(self, "offset:y", 0, 0.1).set_trans(Tween.TRANS_SINE)
		tween.chain().tween_property(self, "scale:x", _original_scale, 0.1).set_trans(Tween.TRANS_SINE)
		tween.chain().tween_property(self, "scale:y", _original_scale, 0.1).set_trans(Tween.TRANS_SINE)
