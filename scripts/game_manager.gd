extends Node

var options_menu = preload("uid://2ktt57lm6wu0").instantiate()

var sfx_volume : float = 5.0
var music_volume : float = 5.0

var is_game_over: bool = false

var fear: int:
	set(val):
		var diff = val - fear
		fear = val
		on_fear.emit(diff)

signal on_fear(incr: int)
signal game_over_triggered
signal toggle_options_visible

func _init() -> void:
	self.on_fear.connect(self._on_fear)

func _ready() -> void:
	get_tree().root.add_child.call_deferred(options_menu)

func _on_fear(_incr: int) -> void:
	if fear >= 100 and not is_game_over:
		is_game_over = true 
		self.game_over()

func options_visible():
	toggle_options_visible.emit()

func game_over() -> void:
	game_over_triggered.emit()

func game_restart() -> void:
	self.fear = 0
	is_game_over = false 
	get_tree().reload_current_scene()

func set_sfx_volume(val: float) -> void:
	sfx_volume = linear_to_db(val)
	
	var sfx_index = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(sfx_index, sfx_volume)

func set_music_volume(val: float) -> void:
	music_volume = linear_to_db(val)
	
	var sfx_index= AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(sfx_index, sfx_volume)

const TITLESCREEN = preload("uid://d2h0hblq55p8p")
