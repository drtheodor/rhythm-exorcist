extends CanvasLayer

@export var next_level_num: int = 2
@export var auto_advance: bool = true   # set false when dialogue is wired in

@onready var ui: DialoguePlayer = $DialogueUi

var is_active_interstage : bool = false

func _ready() -> void:
	GameManager.go_interstage.connect(_on_go_interstage)
	ui.dialogue_finished.connect(_advance)

func _on_go_interstage(num: int) -> void:
	if next_level_num - 1 != num:
		return
	
	is_active_interstage = true
	_start()

func _start() -> void:
	show()
	if auto_advance:
		_advance()

func _advance() -> void:
	hide()
	GameManager.advance_to_level(next_level_num)
	is_active_interstage = false
