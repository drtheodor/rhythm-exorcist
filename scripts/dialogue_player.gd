class_name DialoguePlayer
extends Node

signal start_dialogue()
signal dialogue_typing()
signal dialogue_finished()

@export_file("*.json") var scene_text_file

var scene_text = {}
var selected_text = []
var next = []
var current: String = ""
var current_speaker: String = "speaker1"
var in_progress = false
var is_typing = false
@export var in_main_scene = false

@export var starting_key : String

@export var speaker_1_name : String = "speaker1"
@export var speaker_2_name : String = "speaker2"

@export var backgrounds : Dictionary[String, Texture2D] = {}

@export var typing_speed = 0.25
var typing_counter = 0

@export var end_padding: int = 5

@onready var text_label = %DialogueText
@onready var background_color: ColorRect = $BackgroundColor
@onready var background_texture: TextureRect = $BackgroundTexture
@onready var scene_sprite: Sprite2D = $Scene
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer
@onready var speaker_1: TextureRect = $HBoxContainer/MarginContainer2/TextureRect
@onready var speaker_2: TextureRect = $HBoxContainer/MarginContainer3/TextureRect

@export var scene_images: Dictionary = {}
@export var sfx_sounds: Dictionary = {}

func set_visible(toggle: bool) -> void:
	self.visible = toggle
	background_texture.visible = not in_main_scene
	background_color.visible = not in_main_scene
	scene_sprite.visible = not in_main_scene

func _ready() -> void:
	scene_text = load_scene_text()

func load_scene_text():
	var json_as_text = FileAccess.get_file_as_string(scene_text_file)
	return JSON.parse_string(json_as_text)

func _process(delta) -> void:
	if is_typing:
		typing_counter += delta
		if typing_counter >= typing_speed:
			typing_counter -= typing_speed
			type_text()

func type_text() -> void:
	var count = text_label.get_total_character_count()
	if text_label.visible_characters < count + end_padding:
		text_label.visible_characters += 1
		dialogue_typing.emit()
	else:
		is_typing = false

func finish_typing() -> void:
	text_label.visible_characters = -1
	is_typing = false

func show_text():
	text_label.text = selected_text.pop_front()
	is_typing = true
	text_label.visible_characters = 0

func next_line():
	if selected_text.size() > 0:
		show_text()
	else:
		finish()

func end() -> void:
	in_progress = false
	text_label.text = ""
	set_visible(false)

func finish() -> void:
	in_progress = false
	if len(next) != 0:
		on_display_dialog(next.pop_back())
		return
	text_label.text = ""
	set_visible(false)
	dialogue_finished.emit()

func on_display_dialog(text_key):
	if in_progress:
		next_line()
	elif not is_typing:
		#get_tree().paused = true
		start_dialogue.emit()
		current = text_key
		set_visible(true)
		in_progress = true
		selected_text = process_text_data(scene_text[text_key])
		next_line()

func process_text_data(data:Dictionary) -> Array:
	var color = null
	var font_size = null
	var alignment = null
	
	if data.has("color"):
		color = data["color"]
	else:
		color = "red"
		
	if data.has("font_size"):
		font_size = data["font_size"]
		
	if data.has("alignment"):
		alignment = data["alignment"]
	else:
		var spk = data.get("speaker", current_speaker)
		alignment = "left" if spk == speaker_1_name else "right"
	
	if data.has("next"):
		next.append_array(data["next"])
	
	if data.has("speed"):
		typing_speed = data["speed"]
	
	if data.has("speaker") and current_speaker != data["speaker"]:
		set_speaker(data["speaker"])
	
	if data.has("sfx"):
		var stream = _load_audio(data["sfx"])
		if stream:
			sfx_player.stream = stream
			sfx_player.play()

	if data.has("background"):
		background_texture.texture = backgrounds.get(data["background"])

	if data.has("scene"):
		var key = data["scene"]
		TransitionManager.flash(func():
			if key == null or key == "":
				scene_sprite.visible = false
			else:
				scene_sprite.texture = scene_images.get(key)
				scene_sprite.visible = true
		)

	var texts = data["text"].duplicate()
	
	for i in range(len(texts)):
		if color != null:
			texts[i] = ("[color=%s]" % [color]) + texts[i] + "[/color]"
		if font_size != null:
			texts[i] = ("[font_size=%d]" % [font_size]) + texts[i] + "[/font_size]"
		if alignment != null:
			texts[i] = ("[%s]" % [alignment]) + texts[i] + ("[/%s]" % [alignment])
	
	#print(texts)
	
	return texts

func set_speaker(speak: String):
	if current_speaker == speaker_1_name:
		speaker_1.visible = false
	elif current_speaker == speaker_2_name:
		speaker_2.visible = false
	current_speaker = speak
	if current_speaker == speaker_1_name:
		speaker_1.visible = true
	elif current_speaker == speaker_2_name:
		speaker_2.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not get("visible") or not in_progress:
		return
	if event.is_action_pressed("skip"):
		if is_typing:
			finish_typing()
		else:
			next_line()

func _load_audio(key: String) -> AudioStream:
	for ext in ["mp3", "wav", "ogg"]:
		var path = "res://assets/audio/" + key + "." + ext
		if ResourceLoader.exists(path):
			return load(path)
	return null

func _on_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if in_progress:
				if is_typing:
					finish_typing()
				else:
					next_line()
			else:
				on_display_dialog(starting_key)
