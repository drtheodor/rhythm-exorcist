extends Control

@onready var fear_label = $CanvasLayer/FearText
@onready var fear_bar = $CanvasLayer/FearBar

func _ready() -> void:
	GameManager.on_fear.connect(self._on_fear)
	GameManager.game_over_triggered.connect(_on_game_over_notified)

# TODO: use snake case
func _on_fear(incr: int):
	fear_bar.value = clamp(fear_bar.value + incr, 0, 100)

func _on_game_over_notified() -> void:
	$AnimationPlayer.play("game_over")

func _on_retry_button_pressed() -> void:
	GameManager.game_restart()
