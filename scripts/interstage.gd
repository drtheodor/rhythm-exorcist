extends CanvasLayer

@export var next_level_num: int = 2
@export var auto_advance: bool = true   # set false when dialogue is wired in

func _ready() -> void:
	GameManager.go_interstage.connect(_on_go_interstage)

func _on_go_interstage(num: int) -> void:
	if next_level_num - 1 != num:
		return
	
	_start()

func _start() -> void:
	show()
	if auto_advance:
		_advance()

func _advance() -> void:
	hide()
	GameManager.advance_to_level(next_level_num)
