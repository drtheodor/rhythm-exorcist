extends Node2D

const GAMESCENE = preload("uid://cmuevhd5wo1mp")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_packed(GAMESCENE)

func _on_stage_button_pressed() -> void:
	pass # Replace with function body.

func _on_options_button_pressed() -> void:
	GameManager.options_visible()

func _on_credits_button_pressed() -> void:
	pass # Replace with function body.
