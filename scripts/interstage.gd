extends CanvasLayer

@export var next_level_num: int = 2
@export var auto_advance: bool = true   # set false when dialogue is wired in
@export var face_anim: String = ""      # clara face to play when interstage starts

@onready var ui: DialoguePlayer = $DialogueUi

var is_active_interstage : bool = false

func _ready() -> void:
	GameManager.go_interstage.connect(_on_go_interstage)
	ui.dialogue_finished.connect(_advance)
	ui.face_changed.connect(_on_face_changed)

func _on_go_interstage(num: int) -> void:
	if next_level_num - 1 != num:
		return

	is_active_interstage = true
	_start()

func _start() -> void:
	show()
	if face_anim != "":
		_set_clara_face(face_anim)
	if auto_advance:
		_advance()
	else:
		ui.on_display_dialog(ui.starting_key)

func _advance() -> void:
	hide()
	GameManager.advance_to_level(next_level_num)
	is_active_interstage = false

func _on_face_changed(anim_name: String) -> void:
	if is_active_interstage:
		_set_clara_face(anim_name)

func _set_clara_face(anim_name: String) -> void:
	var clara = get_tree().get_first_node_in_group("Clara") if get_tree() else null
	if clara and clara.faces:
		clara.faces.play(anim_name)
