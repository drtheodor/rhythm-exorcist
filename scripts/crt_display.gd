extends Control

@onready var sub_viewport: SubViewport = $SubViewport
@onready var crt_rect: TextureRect = $CRTRect
var current_scene: Node = null
var _crt_material: ShaderMaterial = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_crt_material = crt_rect.material as ShaderMaterial
	crt_rect.texture = sub_viewport.get_texture()
	_crt_material.set_shader_parameter("tex", sub_viewport.get_texture())
	var initial_scene = preload("uid://d2h0hblq55p8p").instantiate()
	_set_scene(initial_scene)

func change_scene(packed: PackedScene) -> void:
	if current_scene:
		sub_viewport.remove_child(current_scene)
		current_scene.queue_free()
		current_scene = null
	var new_scene = packed.instantiate()
	_set_scene(new_scene)

func _set_scene(scene: Node) -> void:
	sub_viewport.add_child(scene)
	current_scene = scene

func set_crt_enabled(enabled: bool) -> void:
	if enabled:
		crt_rect.material = _crt_material
	else:
		crt_rect.material = null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		event.position -= position
		event.position *= Vector2(Vector2(sub_viewport.size) / size)
	sub_viewport.push_input(event)
