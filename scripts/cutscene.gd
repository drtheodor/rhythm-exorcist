extends Node
class_name Cutscene

enum Type { INTRO, END }
@export var type: Type = Type.INTRO

@onready var dialogue_ui: DialoguePlayer = $DialogueUi
@onready var sfx_type1: AudioStreamPlayer = $GradeCanvas/AudioStreamPlayer1
@onready var sfx_type2: AudioStreamPlayer = $GradeCanvas/AudioStreamPlayer2


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
	"speaking": preload("uid://b564fbiokrogy")
}

const ENDINGS : Dictionary[String, String] = {
	"bad_end_3": "Low Faith Ending (1 of 3)",
	"good_end_3": "High Faith Ending (2 of 3)",
	"secret_end_3": "Secret Ending (3 of 3)"
}

const ENDING_DESC : Dictionary[String, String] = {
	"bad_end_3": "The demon found a new host. On the bright side, you're very comfortable.",
	"good_end_3": "The demon is gone. Technically. You're going to need a few days off.",
	"secret_end_3": "Flawless. The demon didn't stand a chance. Maybe you're cut out for this after all."
}

var ending_key : String
var _prev_hit: int = 0
var _prev_missed: int = 0
var _prev_combos: int = 0

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
				var grade = GameManager.get_grade(GameManager.faith)
				if grade == "S+":
					ending_key = "secret_end_3"
				elif grade in ["S", "A"]:
					ending_key = "good_end_3"
				else:
					ending_key = "bad_end_3"
				dialogue_ui.on_display_dialog(ending_key)
			else:
				await _show_ending_phase()
				await _show_score_phase()
				await _show_grade_phase()
				GameManager.open_title_screen()

func _show_ending_phase() -> void:
	#dialogue_ui.show()
	var ending_title: Label = get_node_or_null("GradeCanvas/EndingTitle")
	var ending_desc: RichTextLabel = get_node_or_null("GradeCanvas/EndingDescription")
	if ending_title and ending_key:
		ending_title.text = ENDINGS[ending_key]
	if ending_desc and ending_key:
		ending_desc.text = ENDING_DESC[ending_key]

	var tween = create_tween()
	tween.tween_property(ending_title, "modulate:a", 1.0, 1.5)
	tween.tween_property(ending_desc, "modulate:a", 1.0, 1.5)
	await tween.finished

func _show_score_phase() -> void:
	#dialogue_ui.show()
	var scores_label: Label = get_node_or_null("GradeCanvas/ScoresDisplay")
	if scores_label:
		scores_label.text = "Notes Hit: %d\nNotes Missed: %d\nCombos Hit: %d" % [
			0, 0, 0
		]

	_prev_hit = 0
	_prev_missed = 0
	_prev_combos = 0
	await _animate_stats()

func _show_grade_phase() -> void:
	#dialogue_ui.show()
	var final_grade: Label = get_node_or_null("GradeCanvas/FinalGrade")
	if final_grade:
		final_grade.text = GameManager.get_grade(0)

	sfx_type2.play()
	var tween : Tween
	if final_grade:
		tween = create_tween()
		tween.tween_property(final_grade, "modulate:a", 1.0, 1.5)
		await tween.finished
	tween = create_tween()
	tween.tween_method(_update_grade, 0., 1., 1.0)
	await tween.finished

	await _wait_for_advance()

func _animate_stats() -> void:
	var tween : Tween
	var scores_label: Label = get_node_or_null("GradeCanvas/ScoresDisplay")
	if scores_label:
		tween = create_tween()
		tween.tween_property(scores_label, "modulate:a", 1.0, 1.5)
		await tween.finished
	tween = create_tween()
	tween.tween_method(_update_label, 0., 1., 2.0)
	await tween.finished

func _update_label(weight: float) -> void:
	var scores_label: Label = get_node_or_null("GradeCanvas/ScoresDisplay")
	if scores_label:
		var hit = int(GameManager.notes_hit * weight)
		var missed = int(GameManager.notes_missed * weight)
		var combos = int(GameManager.combos_hit * weight)

		if hit > _prev_hit or missed > _prev_missed or combos > _prev_combos:
			sfx_type1.play()
			_prev_hit = hit
			_prev_missed = missed
			_prev_combos = combos

		scores_label.text = "Notes Hit: %d\nNotes Missed: %d\nCombos Hit: %d" % [
				hit,
				missed,
				combos
			]

func _update_grade(weight: float) -> void:
	var final_grade: Label = get_node_or_null("GradeCanvas/FinalGrade")
	if final_grade:
		final_grade.text = GameManager.get_grade(int(GameManager.faith * weight))

func _wait_for_advance() -> void:
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("skip"):
			return
