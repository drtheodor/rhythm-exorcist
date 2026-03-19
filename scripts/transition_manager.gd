extends Node

var _material: ShaderMaterial
var _is_transitioning: bool = false

var _canvas: CanvasLayer = null

func _ready() -> void:
	var darken_node = preload("res://scenes/effects/darken_rect.tscn").instantiate()
	_material = darken_node.material as ShaderMaterial
	_material.set_shader_parameter("fade_amount", 1.0)  # start fully black
	_canvas = CanvasLayer.new()
	_canvas.layer = 100
	_canvas.add_child(darken_node)
	call_deferred("_add_canvas_to_viewport")
	call_deferred("_start_fade_in")

func _add_canvas_to_viewport() -> void:
	var crt = get_tree().root.get_node("CRTDisplay")
	crt.sub_viewport.add_child(_canvas)

# Kept for API compatibility — no-op (discrete stages don't suit a subtle pulse)
func set_ambient_pulse(_enabled: bool) -> void:
	pass

func _start_fade_in() -> void:
	_is_transitioning = true
	var tween = create_tween()
	tween.tween_property(_material, "shader_parameter/fade_amount", 0.0, 1.5)
	tween.tween_callback(func(): _is_transitioning = false)

func fade_out() -> void:
	_is_transitioning = true
	var tween = create_tween()
	tween.tween_property(_material, "shader_parameter/fade_amount", 1.0, 0.7)
	await tween.finished

func fade_in() -> void:
	var tween = create_tween()
	tween.tween_property(_material, "shader_parameter/fade_amount", 0.0, 0.5)
	await tween.finished
	_is_transitioning = false

func flash(on_peak: Callable = Callable()) -> void:
	# Quick flash for dialogue scene swaps — does not block caller
	_is_transitioning = true
	var tween = create_tween()
	tween.tween_property(_material, "shader_parameter/fade_amount", 0.65, 0.3)
	if on_peak.is_valid():
		tween.tween_callback(on_peak)
	tween.tween_property(_material, "shader_parameter/fade_amount", 0.0, 0.5)
	tween.tween_callback(func(): _is_transitioning = false)
