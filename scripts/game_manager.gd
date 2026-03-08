extends Node

const MIN_SFX_DB : float = -5.0
const MAX_SFX_DB : float = 5.0
const MIN_MUSIC_DB : float = -5.0
const MAX_MUSIC_DB : float = 5.0

var sfx_volume : float = 0.0
var music_volume : float = 0.0

var fear: int:
	set(val):
		var diff = val - fear
		fear = val
		on_fear.emit(diff)

signal on_fear(incr: int)
signal game_over_triggered

func _init() -> void:
	self.on_fear.connect(self._on_fear)

func _on_fear(_incr: int) -> void:
	if fear >= 100:
		self.game_over()

func game_over() -> void:
	game_over_triggered.emit()
	
func game_restart() -> void:
	self.fear = 0
	get_tree().reload_current_scene()

func set_sfx_volume(val: float) -> void:
	sfx_volume = remap(val, 0, 100, MIN_SFX_DB, MAX_SFX_DB)
	
	var sfx_index= AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(sfx_index, sfx_volume)

func set_music_volume(val: float) -> void:
	music_volume = remap(val, 0, 100, MIN_MUSIC_DB, MAX_MUSIC_DB)
	
	var sfx_index= AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(sfx_index, sfx_volume)

const TITLESCREEN = preload("uid://d2h0hblq55p8p")
