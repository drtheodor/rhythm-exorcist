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
	"scene5": preload("res://assets/textures/scenes/scene5.png"),
	"scene6": preload("res://assets/textures/scenes/scene6.png"),
	"scene7": preload("res://assets/textures/scenes/scene7.png"),
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
			await _show_grade()
			GameManager.open_title_screen()

func _show_grade() -> void:
	var grade_label: Label = get_node_or_null("GradeCanvas/GradeLabel")
	var stats_label: Label = get_node_or_null("GradeCanvas/StatsLabel")
	if grade_label:
		grade_label.text = GameManager.get_grade()
	if stats_label:
		stats_label.text = "Notes Hit: %d\nNotes Missed: %d\nCombos Hit: %d" % [
			GameManager.notes_hit,
			GameManager.notes_missed,
			GameManager.combos_hit
		]
	if grade_label:
		grade_label.get_parent().show()
	await _wait_for_advance()

func _wait_for_advance() -> void:
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("skip"):
			return
