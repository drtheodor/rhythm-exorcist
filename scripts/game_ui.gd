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
@onready var symbol_sprites: Array[Sprite2D] = [
	$CanvasLayer/SymbolCross,
	$CanvasLayer/SymbolWater,
	$CanvasLayer/SymbolBell,
	$CanvasLayer/SymbolPenta,
]

func _ready() -> void:
	GameManager.on_fear.connect(self._on_fear)
	GameManager.on_faith.connect(_on_faith)
	GameManager.game_over_triggered.connect(_on_game_over_notified)
	GameManager.go_interstage.connect(_in_scene_dialogue)
	faith_bar.value = GameManager.faith
	_init_symbols()

func _on_fear(incr: int):
	fear_bar.value = clamp(fear_bar.value + incr, 0, 100)

func _on_faith(new_val: int) -> void:
	faith_bar.value = new_val

func _on_game_over_notified() -> void:
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

func _in_scene_dialogue(_num: int) -> void:
	canvas_layer.visible = false
