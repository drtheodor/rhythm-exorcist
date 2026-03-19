extends CanvasLayer

class_name OptionsMenu

@onready var music_vol_label: Label = $VBoxContainer/MarginContainer/VBoxContainer/HBoxContainer/MusicVolLabel
@onready var sfx_vol_label: Label = $VBoxContainer/MarginContainer2/VBoxContainer/HBoxContainer/SfxVolLabel
@onready var crt_label: Label = $VBoxContainer/MarginContainer3/VBoxContainer/HBoxContainer/CrtValueLabel

func _ready() -> void:
	GameManager.toggle_options_visible.connect(self._on_toggle_visible)

func _on_music_volume_value_changed(value: float) -> void:
	music_vol_label.text = "%d" % (value * 100)
	GameManager.set_music_volume(value)

func _on_sfx_volume_value_changed(value: float) -> void:
	sfx_vol_label.text = "%d" % (value * 100)
	GameManager.set_sfx_volume(value)

func _on_crt_toggle_pressed() -> void:
	GameManager.crt_enabled = not GameManager.crt_enabled
	crt_label.text = "ON" if GameManager.crt_enabled else "OFF"

func _on_back_button_pressed() -> void:
	hide()
	GameManager.options_open = false

func _on_toggle_visible() -> void:
	visible = not visible
	GameManager.options_open = visible
