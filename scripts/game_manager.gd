extends Node

var options_menu = preload("uid://2ktt57lm6wu0").instantiate()
var pause_menu = preload("uid://bkre0wsdf58lf").instantiate()
const GAME_LEVEL = preload("uid://cmuevhd5wo1mp")
const LEVEL_SELECT = preload("uid://dro5vu5pw0wrf")
const TITLESCREEN = preload("uid://d2h0hblq55p8p")
const CUTSCENE_INTRO = preload("res://scenes/cutscene_intro.tscn")
const CUTSCENE_END = preload("res://scenes/cutscene_end.tscn")

@export_category("Level 1")
# Current song: test_low_tempo2
@export var level1_audio: AudioStream = preload("uid://c2hprt6p8adds")
@export var level1_midi: MidiResource = preload("uid://ben25xbc4akfs")

@export_category("Level 2")
# Current song: test_low_tempo
@export var level2_audio: AudioStream = preload("uid://xq87kqybxnue")
@export var level2_midi: MidiResource = preload("uid://b8wmtbj54p8q6")

@export_category("Level 3")
# Current song: thick_of_it
@export var level3_audio: AudioStream = preload("uid://dv4sgm03p7cxp")
@export var level3_midi: MidiResource = preload("uid://co1l3tkcbic3i")

@export_category("Level 4")
@export var level4_audio: AudioStream
@export var level4_midi: MidiResource

var current_level_audio: AudioStream = null
var current_level_midi: MidiResource = null

var sfx_volume : float = 5.0
var music_volume : float = 5.0

var is_game_over: bool = false
var options_open: bool = false
var paused: bool = false

var fear: int:
	set(val):
		var diff = val - fear
		fear = val
		on_fear.emit(diff)

signal on_fear(incr: int)
signal game_over_triggered
signal toggle_options_visible
signal pause_game

func _init() -> void:
	self.on_fear.connect(self._on_fear)

func _ready() -> void:
	get_tree().root.add_child.call_deferred(pause_menu)
	get_tree().root.add_child.call_deferred(options_menu)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		if options_open:
			options_visible()
		else:
			get_tree().paused = not paused
			send_pause_game()

func _on_fear(_incr: int) -> void:
	if fear >= 100 and not is_game_over:
		is_game_over = true 
		self.game_over()

func options_visible():
	toggle_options_visible.emit()

func send_pause_game() -> void:
	pause_game.emit()

func set_sfx_volume(val: float) -> void:
	sfx_volume = linear_to_db(val)
	
	var sfx_index = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(sfx_index, sfx_volume)

func set_music_volume(val: float) -> void:
	music_volume = linear_to_db(val)
	
	var sfx_index= AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(sfx_index, sfx_volume)

func game_over() -> void:
	game_over_triggered.emit()

func game_restart() -> void:
	self.fear = 0
	is_game_over = false 
	select_level(current_level_audio, current_level_midi)

func start_level() -> void:
	await TransitionManager.fade_out()
	get_tree().change_scene_to_packed(CUTSCENE_INTRO)
	TransitionManager.fade_in()

func begin_level_1() -> void:
	select_level(level1_audio, level1_midi)

func open_cutscene_end() -> void:
	await TransitionManager.fade_out()
	get_tree().change_scene_to_packed(CUTSCENE_END)
	TransitionManager.fade_in()

func level_completed() -> void:
	if current_level_audio == level4_audio:
		open_cutscene_end()

func select_level(audio: AudioStream, midi: MidiResource) -> void:
	if audio != current_level_audio and midi != current_level_midi:
		current_level_audio = audio
		current_level_midi = midi

	await TransitionManager.fade_out()
	get_tree().change_scene_to_packed(GAME_LEVEL)
	TransitionManager.fade_in()
	await get_tree().scene_changed
	var midi_player: MidiManager = get_tree().get_first_node_in_group("MidiPlayer")
	midi_player.audio = audio
	midi_player.midi = midi
	midi_player.start()

func open_level_select() -> void:
	self.fear = 0
	is_game_over = false
	await TransitionManager.fade_out()
	get_tree().change_scene_to_packed(LEVEL_SELECT)
	TransitionManager.fade_in()

func open_title_screen() -> void:
	self.fear = 0
	is_game_over = false
	await TransitionManager.fade_out()
	get_tree().change_scene_to_packed(TITLESCREEN)
	TransitionManager.fade_in()
