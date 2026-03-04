extends Control

@onready var fear_label = $CanvasLayer/FearLabel
@onready var fear_bar = $CanvasLayer/FearBar

# TODO: this should be tracked somewhere else
var fear: int = 0

func _ready() -> void:
	Signals.IncrementFear.connect(IncrementFear)
	
	# TODO: call this in a setter
	update_ui()

# TODO: use snake case
func IncrementFear(incr: int):
	fear = clamp(fear + incr, 0, 100)
	update_ui()
	
	# TODO: game logic should be tracked not in UI
	if fear >= 100:
		handle_game_over()

func update_ui():
	fear_label.text = "FEAR: " + str(fear) + "%"
	fear_bar.value = fear

func handle_game_over():
	get_tree().reload_current_scene()
