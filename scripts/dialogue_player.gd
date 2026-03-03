class_name DialoguePlayer
extends Node

@export_file("*.json") var scene_text_file

var scene_text = {}
var selected_text = []
var next = []
var current: String = ""
var in_progress = false
var is_typing = false

@export var starting_key : String

@export var typing_speed = 0.25
var typing_counter = 0

@export var end_padding: int = 5

@onready var text_label = $RichTextLabel
@onready var background: ColorRect = $Background

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
	else:
		is_typing = false
		next_line()

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
	background.visible = false

func finish() -> void:
	in_progress = false
	#if len(dialog_options) > 0:
		#show_options()
	if len(next) != 0:
		on_display_dialog(next.pop_front())
		
		return
	
	text_label.text = ""
	background.visible = false

func on_display_dialog(text_key):
	if in_progress and not is_typing:
		next_line()
	elif not is_typing:
		#get_tree().paused = true
		current = text_key
		background.visible = true
		in_progress = true
		selected_text = process_text_data(scene_text[text_key])
		next_line()

func process_text_data(data:Dictionary) -> Array:
	var color = null
	var font_size = null
	var alignment = null
	next = {}
	
	if data.has("color"):
		color = data["color"]
	else:
		color = "red"
		
	if data.has("font_size"):
		font_size = data["font_size"]
	else:
		font_size = 36
		
	if data.has("alignment"):
		alignment = data["alignment"]
	else:
		alignment = "center"
	
	if data.has("next"):
		next = data["next"]
	
	if data.has("speed"):
		typing_speed = data["speed"]

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



func _on_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			pass
			on_display_dialog(starting_key)
