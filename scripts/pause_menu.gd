extends CanvasLayer
class_name PauseMenu

func _ready() -> void:
	GameManager.pause_game.connect(_on_pause)

func _on_resume_button_pressed() -> void:
	get_tree().paused = false
	hide()
	GameManager.paused = false
	if GameManager.options_open:
		GameManager.options_visible()

func _on_options_button_pressed() -> void:
	if not GameManager.options_open:
		GameManager.options_visible()

func _on_level_select_button_pressed() -> void:
	get_tree().paused = false
	hide()
	GameManager.paused = false
	if GameManager.options_open:
		GameManager.options_visible()
	GameManager.open_level_select()

func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	hide()
	GameManager.paused = false
	if GameManager.options_open:
		GameManager.options_visible()
	GameManager.open_title_screen()

func _on_pause() -> void:
	visible = not visible
	GameManager.paused = visible
