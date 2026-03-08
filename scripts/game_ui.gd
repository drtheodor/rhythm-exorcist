extends Control

@onready var fear_label = $CanvasLayer/FearLabel
@onready var fear_bar = $CanvasLayer/FearBar

func _ready() -> void:
	GameManager.on_fear.connect(self._on_fear)

# TODO: use snake case
func _on_fear(incr: int):
	fear_label.text = "FEAR: " + str(GameManager.fear) + "%"
	fear_bar.value = clamp(fear_bar.value + incr, 0, 100)
