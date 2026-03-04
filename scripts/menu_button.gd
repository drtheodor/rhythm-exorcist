extends Button

@export var prefix: String = ">"

var original_text: String

func _ready() -> void:
	original_text = text
	
	mouse_entered.connect(_on_focus_gained)
	focus_entered.connect(_on_focus_gained)
	
	mouse_exited.connect(_on_focus_lost)
	focus_exited.connect(_on_focus_lost)

func _on_focus_gained() -> void:
	if not has_focus():
		grab_focus()
	text = prefix + original_text

func _on_focus_lost() -> void:
	text = original_text
