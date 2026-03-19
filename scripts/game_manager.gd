extends Node

var options_menu = preload("uid://2ktt57lm6wu0").instantiate()
var pause_menu = preload("uid://bkre0wsdf58lf").instantiate()

const GAME_LEVEL = preload("uid://cmuevhd5wo1mp")
const LEVEL_SELECT = preload("uid://dro5vu5pw0wrf")
const TITLESCREEN = preload("uid://d2h0hblq55p8p")
const CUTSCENE_INTRO = preload("res://scenes/cutscene_intro.tscn")
const CUTSCENE_END = preload("res://scenes/cutscene_end.tscn")

var _crt_display: Node = null

var crt_enabled: bool = true:
	set(val):
		crt_enabled = val
		if _crt_display:
			_crt_display.set_crt_enabled(val)

@export_category("Level 1")
# Current song: test_low_tempo2
@export var level1_audio: AudioStream = preload("uid://c2hprt6p8adds")
@export var level1_midi: MidiResource = preload("uid://ben25xbc4akfs")

@export_category("Level 2")
# Current song: test_low_tempo
@export var level2_audio: AudioStream = preload("uid://c2hprt6p8adds")
@export var level2_midi: MidiResource = preload("uid://ben25xbc4akfs")

@export_category("Level 3")
# Current song: thick_of_it
@export var level3_audio: AudioStream = preload("uid://c2hprt6p8adds")
@export var level3_midi: MidiResource = preload("uid://ben25xbc4akfs")

@export_category("Level 4")
@export var level4_audio: AudioStream = preload("uid://c2hprt6p8adds")
@export var level4_midi: MidiResource = preload("uid://ben25xbc4akfs")

var current_level_audio: AudioStream = null
var current_level_midi: MidiResource = null
var current_level_num: int = 0
var animated_level_entry: bool = false

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

var faith: int = 100:
	set(val):
		faith = clamp(val, 0, 100)
		on_faith.emit(faith)

signal on_fear(incr: int)
signal on_faith(new_val: int)
signal game_over_triggered
signal toggle_options_visible
signal pause_game
signal go_interstage(num: int)

func _init() -> void:
	self.on_fear.connect(self._on_fear)

func _get_crt_display() -> Node:
	if _crt_display == null:
		_crt_display = get_tree().root.get_node("CRTDisplay")
	return _crt_display

func _get_sub_viewport() -> SubViewport:
	return _get_crt_display().sub_viewport

func _change_scene(packed: PackedScene) -> void:
	_get_crt_display().change_scene(packed)

func _ready() -> void:
	call_deferred("_add_menus_to_viewport")

func _add_menus_to_viewport() -> void:
	var sv = _get_sub_viewport()
	sv.add_child(pause_menu)
	sv.add_child(options_menu)

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
	animated_level_entry = false
	select_level(current_level_audio, current_level_midi)

func start_level() -> void:
	await TransitionManager.fade_out()
	_change_scene(CUTSCENE_INTRO)
	TransitionManager.fade_in()

func begin_level_1() -> void:
	current_level_num = 1
	animated_level_entry = false
	select_level(level1_audio, level1_midi)

func open_cutscene_end() -> void:
	await TransitionManager.fade_out()
	_change_scene(CUTSCENE_END)
	TransitionManager.fade_in()

func get_grade() -> String:
	if faith == 100: return "S+"
	if faith >= 85:  return "S"
	if faith >= 70:  return "A"
	if faith >= 55:  return "B"
	if faith >= 35:  return "C"
	if faith >= 15:  return "D"
	return "F"

func level_completed() -> void:
	if   current_level_audio == level1_audio: _go_interstage(1)
	elif current_level_audio == level2_audio: _go_interstage(2)
	elif current_level_audio == level3_audio: _go_interstage(3)
	elif current_level_audio == level4_audio: open_cutscene_end()

func _go_interstage(inter_num: int) -> void:
	await TransitionManager.fade_out()
	go_interstage.emit(inter_num)
	TransitionManager.fade_in()

func advance_to_level(num: int) -> void:
	current_level_num = num
	animated_level_entry = true
	match num:
		2: select_level(level2_audio, level2_midi)
		3: select_level(level3_audio, level3_midi)
		4: select_level(level4_audio, level4_midi)

func select_level(audio: AudioStream, midi: MidiResource) -> void:
	if audio != current_level_audio and midi != current_level_midi:
		current_level_audio = audio
		current_level_midi = midi

	await TransitionManager.fade_out()
	_change_scene(GAME_LEVEL)
	TransitionManager.fade_in()
	await get_tree().process_frame
	await get_tree().process_frame
	var midi_player: MidiManager = get_tree().get_first_node_in_group("MidiPlayer")
	midi_player.audio = audio
	midi_player.midi = midi
	midi_player.start()

func open_level_select() -> void:
	self.fear = 0
	is_game_over = false
	await TransitionManager.fade_out()
	_change_scene(LEVEL_SELECT)
	TransitionManager.fade_in()

func open_title_screen() -> void:
	self.fear = 0
	is_game_over = false
	await TransitionManager.fade_out()
	_change_scene(TITLESCREEN)
	TransitionManager.fade_in()
