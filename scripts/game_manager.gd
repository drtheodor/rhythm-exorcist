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
# Current song: stage1
@export var level1_audio: AudioStream = preload("res://stage1.wav")
@export var level1_midi: MidiResource = preload("res://stage1.mid")
@export var level1_tempo: int = 769230

@export_category("Level 2")
# Current song: stage2
@export var level2_audio: AudioStream = preload("res://stage2.wav")
@export var level2_midi: MidiResource = preload("res://stage2.mid")
@export var level2_tempo: int = 631578

@export_category("Level 3")
# Current song: stage3
@export var level3_audio: AudioStream = preload("res://stage3.wav")
@export var level3_midi: MidiResource = preload("res://stage3.mid")
@export var level3_tempo: int = 480000

@export_category("Level 4")
@export var level4_audio: AudioStream = preload("uid://c2hprt6p8adds")
@export var level4_midi: MidiResource = preload("uid://ben25xbc4akfs")

var current_level_audio: AudioStream = null
var current_level_midi: MidiResource = null
var current_level_tempo: int = 0
var current_level_num: int = 0
var animated_level_entry: bool = false

var sfx_volume : float = 5.0
var music_volume : float = 5.0

var is_game_over: bool = false
var options_open: bool = false
var paused: bool = false
var _interstage3_in_progress: bool = false

var notes_hit: int = 0:
	set(val):
		notes_hit = val
		note_hit.emit()
var notes_missed: int = 0
var combos_hit: int = 0

var fear: int:
	set(val):
		var diff = val - fear
		fear = val
		on_fear.emit(diff)

var faith: int = 100:
	set(val):
		if is_game_over and val < faith:
			return
		faith = clamp(val, 0, 100)
		on_faith.emit(faith)

signal on_fear(incr: int)
signal on_faith(new_val: int)
signal on_combo
signal note_hit
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
		# is_game_over = true 
		# self.game_over()
		return
		# To enable GOD MODE

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
	_interstage3_in_progress = false
	notes_hit = 0
	notes_missed = 0
	combos_hit = 0
	animated_level_entry = false
	select_level(current_level_audio, current_level_midi, current_level_tempo)

func start_level() -> void:
	await TransitionManager.fade_out()
	_change_scene(CUTSCENE_INTRO)
	TransitionManager.fade_in()

func begin_level_1() -> void:
	current_level_num = 1
	animated_level_entry = false
	# Load the game scene so interstage nodes are in the tree, then trigger interstage 0
	current_level_audio = level1_audio
	current_level_midi = level1_midi
	await TransitionManager.fade_out()
	_change_scene(GAME_LEVEL)
	TransitionManager.fade_in()
	await get_tree().process_frame
	await get_tree().process_frame
	_go_interstage(0)

func open_cutscene_end() -> void:
	await TransitionManager.fade_out()
	_change_scene(CUTSCENE_END)
	TransitionManager.fade_in()

func get_grade(faith_: int) -> String:
	if faith_ == 100: return "S+"
	if faith_ >= 85:  return "S"
	if faith_ >= 70:  return "A"
	if faith_ >= 55:  return "B"
	if faith_ >= 35:  return "C"
	if faith_ >= 15:  return "D"
	return "F"

func level_completed() -> void:
	if _interstage3_in_progress:
		return
	if current_level_num <= 3:
		_go_interstage(current_level_num)
	else:
		open_cutscene_end()

func _go_interstage(inter_num: int) -> void:
	if inter_num == 0:
		# Interstage 0: pre-gameplay intro, use existing fade
		await TransitionManager.fade_out()
		go_interstage.emit(inter_num)
		for node in get_tree().get_nodes_in_group("GameplayLayer"):
			node.hide()
		for node in get_tree().get_first_node_in_group("MidiPlayer").get_children():
			if node.has_method("hide"):
				node.hide()
		TransitionManager.fade_in()
		return

	# Interstages 1-3: slide gameplay down to reveal interstage
	go_interstage.emit(inter_num)

	var slide_tween = get_tree().create_tween()
	slide_tween.set_parallel(true)

	for node in get_tree().get_nodes_in_group("GameplayLayer"):
		slide_tween.tween_property(node, "position:y", node.position.y + 120.0, 1.5) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	for node in get_tree().get_first_node_in_group("MidiPlayer").get_children():
		if "position" in node and not node.is_in_group("GameplayLayer"):
			slide_tween.tween_property(node, "position:y", node.position.y + 120.0, 1.5) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	await slide_tween.finished

	for node in get_tree().get_nodes_in_group("GameplayLayer"):
		node.hide()
	for node in get_tree().get_first_node_in_group("MidiPlayer").get_children():
		if node.has_method("hide"):
			node.hide()
	
	var clara : Clara = get_tree().get_first_node_in_group("Clara")
	if clara:
		if inter_num == 3:
			clara.hide()
		elif inter_num == 2:
			clara._start_reaction("d2", 50, 1)
		else:
			clara._start_reaction("d1", 50, 1)
	
	var demonface : Demonface = get_tree().get_first_node_in_group("Demonface")
	if demonface and inter_num == 3:
		demonface.start()
		demonface.show()

func advance_to_level(num: int) -> void:
	if in_level_transition:
		return

	self.fear = 0
	is_game_over = false
	current_level_num = num
	animated_level_entry = true
	match num:
		1: select_level(level1_audio, level1_midi, level1_tempo)
		2: select_level(level2_audio, level2_midi, level2_tempo)
		3: select_level(level3_audio, level3_midi, level3_tempo)
		4: select_level(level4_audio, level4_midi, level4_midi.tempo)

var in_level_transition : bool = false

func select_level(audio: AudioStream, midi: MidiResource, tempo: int) -> void:
	if audio != current_level_audio or midi != current_level_midi or current_level_tempo != tempo:
		current_level_audio = audio
		current_level_midi = midi
		current_level_tempo = tempo

	in_level_transition = true

	if animated_level_entry:
		# No fade — slide handles the transition
		_change_scene(GAME_LEVEL)
		await get_tree().process_frame
		await get_tree().process_frame

		if current_level_num == 4:
			_setup_stage4_visuals()

		# Offset all gameplay elements below screen
		for node in get_tree().get_nodes_in_group("GameplayLayer"):
			node.position.y += 120.0
		var midi_player: MidiManager = get_tree().get_first_node_in_group("MidiPlayer")
		for node in midi_player.get_children():
			if "position" in node and not node.is_in_group("GameplayLayer"):
				node.position.y += 120.0

		midi_player.audio = audio
		print(midi.tempo, " -> ", tempo, "; ", midi.division)
		midi.tempo = tempo
		midi_player.midi = midi
		midi_player.start()
		if current_level_num == 3 and not midi_player.flash_trigger.is_connected(_on_flash_trigger):
			midi_player.flash_trigger.connect(_on_flash_trigger, CONNECT_ONE_SHOT)

		# Slide everything up
		var slide_tween = get_tree().create_tween()
		slide_tween.set_parallel(true)
		for node in get_tree().get_nodes_in_group("GameplayLayer"):
			slide_tween.tween_property(node, "position:y", node.position.y - 120.0, 1.5) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		for node in midi_player.get_children():
			if "position" in node and not node.is_in_group("GameplayLayer"):
				slide_tween.tween_property(node, "position:y", node.position.y - 120.0, 1.5) \
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	else:
		# Original flow with fade (restart, level select, etc.)
		await TransitionManager.fade_out()
		_change_scene(GAME_LEVEL)
		TransitionManager.fade_in()
		await get_tree().process_frame
		await get_tree().process_frame

		if current_level_num == 4:
			_setup_stage4_visuals()

		var midi_player: MidiManager = get_tree().get_first_node_in_group("MidiPlayer")
		midi_player.audio = audio
		print(midi.tempo, " -> ", tempo, "; ", midi.division)
		midi.tempo = tempo
		midi_player.midi = midi
		midi_player.start()
		if current_level_num == 3 and not midi_player.flash_trigger.is_connected(_on_flash_trigger):
			midi_player.flash_trigger.connect(_on_flash_trigger, CONNECT_ONE_SHOT)

	in_level_transition = false

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

func _setup_stage4_visuals() -> void:
	for node in get_tree().get_nodes_in_group("Interstage3Hide"):
		node.hide()
	var clara = get_tree().get_first_node_in_group("Clara")
	if clara:
		clara.hide()
	var demonface: Demonface = get_tree().get_first_node_in_group("Demonface")
	if demonface:
		demonface.show()
		demonface.activate()

func _on_flash_trigger() -> void:
	_interstage3_in_progress = true

	# Create white flash overlay above everything
	var brighten = preload("res://scenes/effects/brighten_rect.tscn").instantiate()
	var brighten_canvas = CanvasLayer.new()
	brighten_canvas.layer = 101
	brighten_canvas.add_child(brighten)
	_get_sub_viewport().add_child(brighten_canvas)
	var bright_mat = brighten.material as ShaderMaterial

	# Play lightbreak sound
	var sfx = AudioStreamPlayer.new()
	sfx.stream = preload("res://assets/audio/lightbreak.mp3")
	sfx.bus = "SFX"
	_get_sub_viewport().add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

	# Flash to white (instant)
	bright_mat.set_shader_parameter("bright_amount", 1.0)

	# While screen is white, hide gameplay elements
	for node in get_tree().get_nodes_in_group("GameplayLayer"):
		node.hide()
	for node in get_tree().get_nodes_in_group("Interstage3Hide"):
		node.hide()
	var game_ui = get_tree().get_first_node_in_group("GameUI")
	if game_ui:
		game_ui.hide()
		var ui_canvas = game_ui.get_node_or_null("CanvasLayer")
		if ui_canvas:
			ui_canvas.hide()
	var clara = get_tree().get_first_node_in_group("Clara")
	if clara:
		clara.hide()
	var midi_player = get_tree().get_first_node_in_group("MidiPlayer")
	if midi_player:
		for child in midi_player.get_children():
			if child.has_method("hide"):
				child.hide()

	# Show demon (off-screen at animation start)
	var demonface: Demonface = get_tree().get_first_node_in_group("Demonface")
	if demonface:
		demonface.show()
		demonface.start()

	# Fade white away to reveal black interstage screen
	var tween2 = create_tween()
	tween2.tween_property(bright_mat, "shader_parameter/bright_amount", 0.0, 0.3)
	await tween2.finished
	brighten_canvas.queue_free()

	# Wait for demon animation to finish before starting dialogue
	if demonface:
		await demonface.faces.animation_finished

	# Now trigger interstage dialogue
	go_interstage.emit(3)
	_interstage3_in_progress = false
