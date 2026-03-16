extends Node

enum Type { INTRO, END }
@export var type: Type = Type.INTRO

@onready var dialogue_ui: DialoguePlayer = $DialogueUi

const SCENE_BACKGROUNDS: Dictionary[String, Texture2D] = {
	"scene1": preload("res://assets/textures/scenes/scene1.png"),
	"scene2": preload("res://assets/textures/scenes/scene2.png"),
	"scene3a": preload("res://assets/textures/scenes/scene3a.png"),
	"scene3b": preload("res://assets/textures/scenes/scene3b.png"),
	"scene4": preload("res://assets/textures/scenes/scene4.png"),
}

const SFX_SOUNDS: Dictionary[String, AudioStream] = {
	# "writing": preload("res://assets/sfx/writing.wav"),
}

func _ready() -> void:
	dialogue_ui.backgrounds = SCENE_BACKGROUNDS
	dialogue_ui.scene_images = SCENE_BACKGROUNDS
	dialogue_ui.sfx_sounds = SFX_SOUNDS
	dialogue_ui.dialogue_finished.connect(_on_dialogue_finished)
	dialogue_ui.on_display_dialog(dialogue_ui.starting_key)

func _on_dialogue_finished() -> void:
	match type:
		Type.INTRO:
			GameManager.begin_level_1()
		Type.END:
			GameManager.open_title_screen()
