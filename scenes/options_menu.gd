extends Node2D

class_name OptionsMenu

@onready var music_vol_label: Label = $VBoxContainer/VBoxContainer/VBoxContainer/HBoxContainer/MusicVolLabel
@onready var sfx_vol_label: Label = $VBoxContainer/VBoxContainer2/VBoxContainer/HBoxContainer/SfxVolLabel

func _ready() -> void:
	GameManager.toggle_options_visible.connect(self._on_toggle_visible)

func _on_music_volume_value_changed(value: float) -> void:
	music_vol_label.text = "%d" % (value * 100)
	GameManager.set_music_volume(value)

func _on_sfx_volume_value_changed(value: float) -> void:
	sfx_vol_label.text = "%d" % (value * 100)
	GameManager.set_sfx_volume(value)

func _on_back_button_pressed() -> void:
	hide()

func _on_toggle_visible() -> void:
	visible = not visible
