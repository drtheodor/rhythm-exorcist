extends Node2D


func _on_level_1_button_pressed() -> void:
	GameManager.select_level(GameManager.level1_audio, GameManager.level1_midi)

func _on_level_2_button_pressed() -> void:
	GameManager.select_level(GameManager.level2_audio, GameManager.level2_midi)

func _on_level_3_button_pressed() -> void:
	GameManager.select_level(GameManager.level3_audio, GameManager.level3_midi)

func _on_level_4_button_pressed() -> void:
	GameManager.select_level(GameManager.level4_audio, GameManager.level4_midi)

func _on_back_button_pressed() -> void:
	GameManager.open_title_screen()
