extends Control

const SYMBOL_REGIONS: Array[Rect2] = [
	Rect2(0, 16, 24, 24),
	Rect2(24, 16, 24, 24),
	Rect2(48, 16, 24, 24),
	Rect2(72, 16, 24, 24),
]
const SYMBOL_HEIGHT: int = 24

@onready var canvas_layer: CanvasLayer = $CanvasLayer

@onready var fear_label = $CanvasLayer/FearText
@onready var fear_bar = $CanvasLayer/FearBar
@onready var faith_bar = $CanvasLayer/FaithBar
@onready var poss_bar = $CanvasLayer/PossBar
@onready var symbol_sprites: Array[Sprite2D] = [
	$CanvasLayer/SymbolCross,
	$CanvasLayer/SymbolWater,
	$CanvasLayer/SymbolBell,
	$CanvasLayer/SymbolPenta,
]

func _ready() -> void:
	GameManager.on_fear.connect(self._on_fear)
	GameManager.on_faith.connect(_on_faith)
	GameManager.on_game_over.connect(_on_game_over_notified)
	GameManager.go_interstage.connect(_in_scene_dialogue)
	GameManager.note_hit.connect(_on_note_hit)
	faith_bar.value = GameManager.faith
	poss_bar.value = 100
	var should_slide = GameManager.animated_level_entry
	_init_symbols()
	if should_slide:
		canvas_layer.offset.y = 120.0
		var tween = create_tween()
		tween.tween_property(canvas_layer, "offset:y", 0.0, 1.5) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _on_note_hit() -> void:
	var midi_player = get_tree().get_first_node_in_group("MidiPlayer") as MidiManager
	if midi_player and midi_player.song_duration > 0.0:
		poss_bar.value = (1.0 - midi_player.current_time / midi_player.song_duration) * 100.0

func _on_fear(incr: int):
	fear_bar.value = clamp(fear_bar.value + incr, 0, 100)
	if incr > 0:
		_shake_ui()

func _shake_ui() -> void:
	var tween = create_tween()
	tween.tween_property(canvas_layer, "offset:x", 2.0, 0.03)
	tween.tween_property(canvas_layer, "offset:x", -2.0, 0.03)
	tween.tween_property(canvas_layer, "offset:x", 1.0, 0.03)
	tween.tween_property(canvas_layer, "offset:x", 0.0, 0.03)

func _on_faith(new_val: int) -> void:
	faith_bar.value = new_val

func _on_game_over_notified() -> void:
	if GameManager.current_level_num >= 2:
		var total = GameManager.notes_hit + GameManager.notes_missed
		var miss_ratio = float(GameManager.notes_missed) / max(total, 1)
		var jumpscare_chance = miss_ratio * 0.5
		if randf() < jumpscare_chance:
			$AnimationPlayer.play("game_over_jump1")
			return
	$AnimationPlayer.play("game_over")

func _init_symbols() -> void:
	for i in range(symbol_sprites.size()):
		symbol_sprites[i].region_rect = SYMBOL_REGIONS[i]
	var idx = GameManager.current_level_num - 1
	if idx >= 0 and idx < symbol_sprites.size():
		var red_rect = SYMBOL_REGIONS[idx]
		red_rect.position.y += SYMBOL_HEIGHT
		symbol_sprites[idx].region_rect = red_rect
		if GameManager.animated_level_entry:
			GameManager.animated_level_entry = false
			_shake_symbol(symbol_sprites[idx])

func _shake_symbol(sprite: Sprite2D) -> void:
	var tween = create_tween()
	var base = sprite.offset
	tween.tween_property(sprite, "offset", base + Vector2(0, 2), 0.1)
	tween.tween_property(sprite, "offset", base + Vector2(0, -2), 0.1)
	tween.tween_property(sprite, "offset", base, 0.1)

func _on_retry_button_pressed() -> void:
	GameManager.game_restart()

func _in_scene_dialogue(num: int) -> void:
	if num == 0:
		canvas_layer.visible = false
		return
	var tween = create_tween()
	tween.tween_property(canvas_layer, "offset:y", 120.0, 1.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tween.finished
	canvas_layer.visible = false
