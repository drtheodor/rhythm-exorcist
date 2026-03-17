extends Node

@export var next_level_num: int = 2
@export var auto_advance: bool = true   # set false when dialogue is wired in

func _ready() -> void:
	if auto_advance:
		_advance()

func _advance() -> void:
	GameManager.advance_to_level(next_level_num)
