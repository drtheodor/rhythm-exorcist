extends Node
class_name Cutscene

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
	"scene8": preload("res://assets/textures/scenes/scene8.png"),
}

const SFX_SOUNDS: Dictionary[String, AudioStream] = {
	"speaking": preload("uid://4wvhkiyrh3a8")
}

func _ready() -> void:
	dialogue_ui.backgrounds = SCENE_BACKGROUNDS
	dialogue_ui.scene_images = SCENE_BACKGROUNDS
	dialogue_ui.sfx_sounds = SFX_SOUNDS
	dialogue_ui.dialogue_finished.connect(_on_dialogue_finished)
	if type == Type.END:
		dialogue_ui.speaker_2.texture = preload("res://assets/textures/character_portrait_3.png")
	dialogue_ui.on_display_dialog(dialogue_ui.starting_key)

func _on_dialogue_finished() -> void:
	match type:
		Type.INTRO:
			GameManager.begin_level_1()
		Type.END:
			if dialogue_ui.current == "end_mirror":
				var faith = GameManager.faith
				var ending_key: String
				if faith == 100:
					ending_key = "secret_end_3"
				elif faith >= 60:
					ending_key = "good_end_3"
				else:
					ending_key = "bad_end_3"
				dialogue_ui.on_display_dialog(ending_key)
			else:
				await _show_grade()
				GameManager.open_title_screen()

func _show_grade() -> void:
	var grade_label: Label = get_node_or_null("GradeCanvas/GradeLabel")
	var stats_label: Label = get_node_or_null("GradeCanvas/StatsLabel")
	if grade_label:
		grade_label.text = GameManager.get_grade(0)
	if stats_label:
		stats_label.text = "Notes Hit: %d\nNotes Missed: %d\nCombos Hit: %d" % [
			0, 0, 0
		]
	if grade_label:
		grade_label.get_parent().show()
	
	await _animate_score()
	await _wait_for_advance()

func _animate_score() -> void:
	var tween = create_tween()
	tween.tween_method(_update_label, 0., 1., 2.0)
	tween.tween_method(_update_grade, 0., 1., 2.0)
	await tween.finished

func _update_label(weight: float) -> void:
	var stats_label: Label = get_node_or_null("GradeCanvas/StatsLabel")
	if stats_label:
		stats_label.text = "Notes Hit: %d\nNotes Missed: %d\nCombos Hit: %d" % [
				int(GameManager.notes_hit * weight),
				int(GameManager.notes_missed * weight),
				int(GameManager.combos_hit * weight)
			]

func _update_grade(weight: float) -> void:
	var grade_label: Label = get_node_or_null("GradeCanvas/GradeLabel")
	if grade_label:
		grade_label.text = GameManager.get_grade(int(GameManager.faith * weight))

func _wait_for_advance() -> void:
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("skip"):
			return
