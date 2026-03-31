extends Control

@onready var sub_viewport: SubViewport = $SubViewport
@onready var crt_rect: TextureRect = $CRTRect
var current_scene: Node = null
var _crt_material: ShaderMaterial = null
var glitch_effect: Node = null
var glitch_intensity: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_crt_material = crt_rect.material as ShaderMaterial
	crt_rect.texture = sub_viewport.get_texture()
	_crt_material.set_shader_parameter("tex", sub_viewport.get_texture())
	var initial_scene = preload("uid://d2h0hblq55p8p").instantiate()
	_set_scene(initial_scene)

	glitch_effect = preload("res://scenes/effects/glitch_effect_rect.tscn").instantiate()
	sub_viewport.add_child(glitch_effect)
	update_glitch_parameters()

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

func update_glitch_parameters() -> void:
	if glitch_effect == null or glitch_effect.get_child_count() == 0:
		return

	var color_rect = glitch_effect.get_child(0) as ColorRect
	if color_rect == null:
		return

	var glitch_material = color_rect.material as ShaderMaterial
	if glitch_material == null:
		return

	glitch_material.set_shader_parameter("glitch_intensity", glitch_intensity)

	var tile_coverage = min(glitch_intensity * 1.5, 1.0)
	glitch_material.set_shader_parameter("tile_coverage", tile_coverage)

	var max_tiles = 2025
	var max_tile_index = int(1.0 + glitch_intensity * float(max_tiles - 1))
	glitch_material.set_shader_parameter("max_tile_index", max_tile_index)
