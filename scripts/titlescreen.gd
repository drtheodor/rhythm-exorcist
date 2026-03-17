extends Node2D

func _ready() -> void:
	TransitionManager.set_ambient_pulse(true)

func _on_play_button_pressed() -> void:
	GameManager.start_level()

func _on_stage_button_pressed() -> void:
	GameManager.open_level_select()

func _on_options_button_pressed() -> void:
	GameManager.options_visible()

func _on_credits_button_pressed() -> void:
	pass # Replace with function body.
