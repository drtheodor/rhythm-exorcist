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
@export var level1_hit_window: float = 1.0

@export_category("Level 2")
# Current song: stage2
@export var level2_audio: AudioStream = preload("res://stage2.wav")
@export var level2_midi: MidiResource = preload("res://stage2.mid")
@export var level2_tempo: int = 631578
@export var level2_hit_window: float = 2.0

@export_category("Level 3")
# Current song: stage3
@export var level3_audio: AudioStream = preload("res://stage3.wav")
@export var level3_midi: MidiResource = preload("res://stage3.mid")
@export var level3_tempo: int = 480000
@export var level3_hit_window: float = 4.0

@export_category("Level 4")
@export var level4_audio: AudioStream = preload("res://stage4.wav")
@export var level4_midi: MidiResource = preload("res://stage4.mid")
@export var level4_hit_window: float = 4.0

@export_category("Stage 4 Finale")
@export var finale_glitch_start_intensity: float = 1.0
@export var finale_glitch_end_intensity: float = 0.0
@export var finale_glitch_start_coverage: float = 0
@export var finale_glitch_end_coverage: float = 0.5
@export var finale_glitch_duration: float = 5.0
@export var finale_brighten_delay: float = 3.0
@export var finale_brighten_duration: float = 5.0
@export var finale_music_fade_duration: float = 7.0
@export var finale_total_duration: float = 8.0
@export var finale_screen_shake_intensity: float = 20.0
@export var finale_screen_shake_duration: float = 0.8
@export var finale_white_hold_duration: float = 3.0
@export var finale_last_scream_time: float = 10.5

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
var _stage3_glitch_active: bool = false

var notes_hit: int = 0:
	set(val):
		notes_hit = val
		note_hit.emit()
var notes_missed: int = 0
var combos_hit: int = 0:
	set(val):
		var diff = val - combos_hit
		
		for i in range(diff):
			on_combo.emit()

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
signal note_hit
signal on_combo
signal on_game_over
signal toggle_options_visible
signal pause_game
signal go_interstage(num: int)

func _init() -> void:
	self.on_fear.connect(self._on_fear)

func _get_crt_display() -> Node:
	if self._crt_display == null:
		self._crt_display = get_tree().root.get_node("CRTDisplay")
	return self._crt_display

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
	if Input.is_action_just_pressed("pause") and (current_level_audio != null or self.options_open):
		if self.options_open:
			options_visible()
		else:
			get_tree().paused = not self.paused
			send_pause_game()

	if _stage3_glitch_active:
		var midi_player = get_tree().get_first_node_in_group("MidiPlayer") as MidiManager
		if midi_player and midi_player.song_duration > 0.0:
			var progress = midi_player.current_time / midi_player.song_duration
			var glitch_intensity = 0.0
			var glitch_coverage = 0.0
			if progress >= 0.7:
				glitch_intensity = 1.0 + (progress - 0.7) * 31.667
				glitch_coverage = (progress - 0.7) * 1.667
			var crt_display = _get_crt_display()
			if crt_display:
				crt_display.glitch_intensity = glitch_intensity
				crt_display.glitch_coverage = glitch_coverage
				crt_display.update_glitch_parameters()

func _on_fear(_incr: int) -> void:
	if self.fear >= 100 and not self.is_game_over:
		self.is_game_over = true 
		self.game_over()
		# return
		# GODMODE

func options_visible():
	self.toggle_options_visible.emit()

func send_pause_game() -> void:
	self.pause_game.emit()

func set_sfx_volume(val: float) -> void:
	sfx_volume = linear_to_db(val)
	
	var sfx_index = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(sfx_index, sfx_volume)

func set_music_volume(val: float) -> void:
	music_volume = linear_to_db(val)
	
	var sfx_index = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(sfx_index, sfx_volume)

func game_over() -> void:
	self.on_game_over.emit()

func game_restart() -> void:
	self._reset(true)
	_interstage3_in_progress = false
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
	if faith_ >= 80: return "S+"
	if faith_ >= 65: return "S"
	if faith_ >= 50: return "A"
	if faith_ >= 30: return "B"
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
		else:
			clara.show()
	
	var demonface : Demonface = get_tree().get_first_node_in_group("Demonface")
	if demonface and inter_num == 3:
		demonface.start()
		demonface.show()

func advance_to_level(num: int) -> void:
	if self.in_level_transition:
		return
	
	self._reset()
	self.current_level_num = num
	self.animated_level_entry = true
	
	match num:
		1: select_level(level1_audio, level1_midi, level1_tempo)
		2: select_level(level2_audio, level2_midi, level2_tempo)
		3: select_level(level3_audio, level3_midi, level3_tempo)
		4: select_level(level4_audio, level4_midi, level4_midi.tempo)

var in_level_transition : bool = false

func select_level(audio: AudioStream, midi: MidiResource, tempo: int) -> void:
	if audio != self.current_level_audio or midi != self.current_level_midi or tempo != self.current_level_tempo:
		self.current_level_audio = audio
		self.current_level_midi = midi
		self.current_level_tempo = tempo

	self.in_level_transition = true

	if self.animated_level_entry:
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
		if current_level_num == 3:
			_stage3_glitch_active = true
			if not midi_player.flash_trigger.is_connected(_on_flash_trigger):
				midi_player.flash_trigger.connect(_on_flash_trigger, CONNECT_ONE_SHOT)
		if current_level_num == 4:
			if not midi_player.flash_trigger.is_connected(_on_stage4_finale):
				midi_player.flash_trigger.connect(_on_stage4_finale, CONNECT_ONE_SHOT)

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
		if current_level_num == 3:
			_stage3_glitch_active = true
			if not midi_player.flash_trigger.is_connected(_on_flash_trigger):
				midi_player.flash_trigger.connect(_on_flash_trigger, CONNECT_ONE_SHOT)
		if current_level_num == 4:
			if not midi_player.flash_trigger.is_connected(_on_stage4_finale):
				midi_player.flash_trigger.connect(_on_stage4_finale, CONNECT_ONE_SHOT)

	self.in_level_transition = false

func open_level_select() -> void:
	self._reset(true)
	
	await TransitionManager.fade_out()
	_change_scene(LEVEL_SELECT)
	TransitionManager.fade_in()

func open_title_screen() -> void:
	self._reset(true)
	
	await TransitionManager.fade_out()
	_change_scene(TITLESCREEN)
	TransitionManager.fade_in()

func _reset(all: bool = false):
	self.fear = 0
	self.is_game_over = false
	_stage3_glitch_active = false
	var crt_display = _get_crt_display()
	if crt_display and current_level_num != 4:
		crt_display.glitch_intensity = 0.0
		crt_display.glitch_coverage = 0.0
		crt_display.update_glitch_parameters()
	if all:
		#self.faith = 100
		self.notes_hit = 0
		self.notes_missed = 0
		self.combos_hit = 0
		self.animated_level_entry = false

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
	_stage3_glitch_active = false

	var crt_display = _get_crt_display()
	if crt_display:
		crt_display.glitch_intensity = 0.0
		crt_display.glitch_coverage = 0.0
		crt_display.update_glitch_parameters()

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

func _on_stage4_finale() -> void:
	var brighten = preload("res://scenes/effects/brighten_rect.tscn").instantiate()
	var brighten_canvas = CanvasLayer.new()
	brighten_canvas.layer = 101
	brighten_canvas.add_child(brighten)
	_get_sub_viewport().add_child(brighten_canvas)
	var bright_mat = brighten.material as ShaderMaterial
	bright_mat.set_shader_parameter("bright_amount", 0.0)

	var demonface: Demonface = get_tree().get_first_node_in_group("Demonface")
	if demonface:
		demonface.scream_triggered.connect(func():
			screen_shake(finale_screen_shake_duration, finale_screen_shake_intensity)
		)
		demonface.end()

	var music_bus_index = AudioServer.get_bus_index("Music")
	var original_music_db = AudioServer.get_bus_volume_db(music_bus_index)

	var glitch_tween = create_tween()
	glitch_tween.tween_method(func(val: float):
		var crt = _get_crt_display()
		if crt:
			crt.glitch_intensity = lerpf(finale_glitch_start_intensity, finale_glitch_end_intensity, val)
			crt.glitch_coverage = lerpf(finale_glitch_start_coverage, finale_glitch_end_coverage, val)
			crt.update_glitch_parameters()
	, 0.0, 1.0, finale_total_duration)

	var brighten_tween = create_tween()
	brighten_tween.tween_interval(finale_brighten_delay)
	brighten_tween.tween_method(func(val: float):
		bright_mat.set_shader_parameter("bright_amount", val)
	, 0.0, 1.0, finale_brighten_duration)

	var music_tween = create_tween()
	music_tween.tween_method(func(val: float):
		AudioServer.set_bus_volume_db(music_bus_index, lerpf(original_music_db, -80.0, val))
	, 0.0, 1.0, finale_music_fade_duration)

	await get_tree().create_timer(finale_total_duration).timeout

	await get_tree().create_timer(finale_white_hold_duration).timeout

	var final_scream = AudioStreamPlayer.new()
	final_scream.stream = preload("res://assets/audio/beastscream2.mp3")
	final_scream.bus = "SFX"
	_get_sub_viewport().add_child(final_scream)
	final_scream.play()

	var crt = _get_crt_display()
	var shake_tween = create_tween()
	shake_tween.set_ease(Tween.EASE_OUT)
	shake_tween.set_trans(Tween.TRANS_QUAD)
	var shake_count = int(2.0 * 20)
	var frame_duration = 2.0 / shake_count
	for i in range(shake_count):
		var progress = float(i) / shake_count
		var current_intensity = 25.0 * (1.0 - progress)
		var offset = Vector2(randf_range(-current_intensity, current_intensity), randf_range(-current_intensity, current_intensity))
		shake_tween.tween_property(crt, "position", offset, frame_duration)

	await get_tree().create_timer(1.2).timeout

	glitch_tween.kill()
	brighten_tween.kill()
	music_tween.kill()
	shake_tween.kill()

	final_scream.stop()
	final_scream.queue_free()

	if crt:
		crt.position = Vector2.ZERO

	var crt_display = _get_crt_display()
	if crt_display:
		crt_display.glitch_intensity = 0.0
		crt_display.glitch_coverage = 0.0
		crt_display.update_glitch_parameters()
	AudioServer.set_bus_volume_db(music_bus_index, original_music_db)
	brighten_canvas.queue_free()

	_change_scene(CUTSCENE_END)

func screen_shake(duration: float = 1.2, intensity: float = 15.0) -> void:
	var crt = _get_crt_display()
	if not crt:
		return

	var sfx = AudioStreamPlayer.new()
	sfx.stream = preload("res://assets/audio/thump.mp3")
	sfx.bus = "SFX"
	sfx.volume_db = 6.0
	_get_sub_viewport().add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

	var shake_count = int(duration * 20)
	var frame_duration = duration / shake_count

	for i in range(shake_count):
		var progress = float(i) / shake_count
		var current_intensity = intensity * (1.0 - progress)
		var offset = Vector2(randf_range(-current_intensity, current_intensity), randf_range(-current_intensity, current_intensity))
		tween.tween_property(crt, "position", offset, frame_duration)

	tween.tween_property(crt, "position", Vector2.ZERO, 0.1)
