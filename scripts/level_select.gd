extends Node2D


func _on_level_1_button_pressed() -> void:
	GameManager.begin_level_1()

func _on_level_2_button_pressed() -> void:
	GameManager.advance_to_level(2)

func _on_level_3_button_pressed() -> void:
	GameManager.advance_to_level(3)

func _on_level_4_button_pressed() -> void:
	GameManager.advance_to_level(4)

func _on_back_button_pressed() -> void:
	GameManager.open_title_screen()
