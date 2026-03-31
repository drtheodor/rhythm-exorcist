extends Node2D
class_name Demonface

@onready var faces: AnimationPlayer = $DemonFaces

var _reaction_timer: float = 0.0
var _reaction_priority: int = 0
var _miss_count: int = 0
var _active: bool = false

@export var misses_before_reaction: int = 4

signal scream_triggered

func _ready() -> void:
	GameManager.on_fear.connect(_on_fear)
	GameManager.on_combo.connect(_on_combo)
	faces.animation_started.connect(_on_animation_changed)

func _process(delta: float) -> void:
	if not _active:
		return
	if _reaction_priority > 0:
		_reaction_timer -= delta
		if _reaction_timer <= 0.0:
			_reaction_priority = 0
			_play_idle()

func start() -> void:
	faces.play("start")

func end() -> void:
	_active = false
	faces.play("end")

func _on_scream() -> void:
	var audio = $DemonAudioStream
	audio.stop()
	audio.play()
	scream_triggered.emit()

func _on_thump() -> void:
	GameManager.screen_shake(1.2, 15.0)

func _on_scream_start() -> void:
	var audio = $DemonAudioStream
	audio.stream = preload("res://assets/audio/beastscream2.mp3")
	audio.play()
	GameManager.screen_shake(1.2, 15.0)

func activate() -> void:
	_active = true
	_miss_count = 0
	_reaction_priority = 0
	_reaction_timer = 0.0
	_play_idle()

func _on_fear(incr: int) -> void:
	if not _active or incr <= 0:
		return
	_miss_count += 1
	var clara = get_tree().get_first_node_in_group("Clara") as Clara
	if not clara:
		return
	if _miss_count < clara.misses_before_reaction:
		return
	_miss_count = 0
	var idx = GameManager.current_level_num - 1
	if idx < 0 or idx >= clara.idle_anims.size():
		return
	if GameManager.fear >= clara.near_death_thresholds[idx]:
		_start_reaction(clara.near_death_miss_anims[idx], clara.near_death_miss_durations[idx], 2)
	else:
		_start_reaction(clara.miss_anims[idx], clara.miss_durations[idx], 1)

func _on_animation_changed(anim: String) -> void:
	if anim == "d2" and GameManager.current_level_num == 4:
		GameManager.screen_shake(0.3, 15.0)
		var audio = $DemonAudioStream
		audio.stream = preload("res://assets/audio/beastscream2.mp3")
		audio.stop()
		audio.play()

func _on_combo() -> void:
	if not _active:
		return
	var clara = get_tree().get_first_node_in_group("Clara") as Clara
	if not clara:
		return
	var idx = GameManager.current_level_num - 1
	if idx < 0 or idx >= clara.combo_anims.size():
		return
	_start_reaction(clara.combo_anims[idx], clara.combo_durations[idx], 1)

func _start_reaction(anim: String, duration: float, priority: int) -> void:
	if priority < _reaction_priority:
		return
	_reaction_priority = priority
	_reaction_timer = duration
	if faces.has_animation(anim):
		faces.play(anim)

func _play_idle() -> void:
	var clara = get_tree().get_first_node_in_group("Clara") as Clara
	if not clara:
		return
	var idx = GameManager.current_level_num - 1
	if idx >= 0 and idx < clara.idle_anims.size():
		var anim = clara.idle_anims[idx]
		if faces.has_animation(anim):
			faces.play(anim)
