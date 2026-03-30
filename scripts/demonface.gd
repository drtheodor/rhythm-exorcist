extends Node2D
class_name Demonface

@onready var faces: AnimationPlayer = $DemonFaces

func start() -> void:
	faces.play("start")
