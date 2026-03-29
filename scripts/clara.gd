extends Node2D

# Index = level - 1. Animation names: "1"–"11", "13", "d1", "d2"
@export var idle_anims: Array[String]             = ["1", "1", "1", "1"]
@export var miss_anims: Array[String]             = ["2", "2", "2", "2"]
@export var near_death_miss_anims: Array[String]  = ["3", "3", "3", "3"]
@export var near_death_thresholds: Array[int]     = [70, 70, 70, 70]
@export var miss_durations: Array[float]          = [1.5, 1.5, 1.5, 1.5]
@export var near_death_miss_durations: Array[float] = [3.0, 3.0, 3.0, 3.0]
@export var combo_anims: Array[String]            = ["1", "1", "1", "1"]
@export var combo_durations: Array[float]         = [1.0, 1.0, 1.0, 1.0]

@onready var faces: AnimationPlayer = $ClaraFaces

@export var misses_before_reaction: int = 4

var _reaction_timer: float = 0.0
var _reaction_priority: int = 0   # 0=idle, 1=miss, 2=near_death_miss
var _miss_count: int = 0
var face_override: bool = false    # when true, gameplay signals don't change face

func _ready() -> void:
	GameManager.on_fear.connect(_on_fear)
	GameManager.on_combo.connect(_on_combo)
	if not face_override:
		_play_idle()

func _process(delta: float) -> void:
	if face_override:
		return
	if _reaction_priority > 0:
		_reaction_timer -= delta
		if _reaction_timer <= 0.0:
			_reaction_priority = 0
			_play_idle()

func _on_fear(incr: int) -> void:
	if face_override:
		return
	if incr <= 0:
		return
	_miss_count += 1
	if _miss_count < misses_before_reaction:
		return
	_miss_count = 0
	var idx = GameManager.current_level_num - 1
	if idx < 0 or idx >= idle_anims.size():
		return
	if GameManager.fear >= near_death_thresholds[idx]:
		_start_reaction(near_death_miss_anims[idx], near_death_miss_durations[idx], 2)
	else:
		_start_reaction(miss_anims[idx], miss_durations[idx], 1)

func _on_combo() -> void:
	if face_override:
		return
	var idx = GameManager.current_level_num - 1
	if idx < 0 or idx >= combo_anims.size():
		return
	_start_reaction(combo_anims[idx], combo_durations[idx], 1)

func _start_reaction(anim: String, duration: float, priority: int) -> void:
	if priority < _reaction_priority:
		return
	_reaction_priority = priority
	_reaction_timer = duration
	faces.play(anim)

func _play_idle() -> void:
	var idx = GameManager.current_level_num - 1
	if idx >= 0 and idx < idle_anims.size():
		faces.play(idle_anims[idx])
