class_name MainViewSwitcher
extends Node2D

@export var display: AnimatedSprite2D
@export var systems_clickable: Clickable
@export var map_clickable: Clickable

signal show_systems()
signal show_map()


func _ready() -> void:
	systems_clickable.clicked.connect(func():
		display.frame = 0
		show_systems.emit()
	)
	map_clickable.clicked.connect(func():
		display.frame = 1
		show_map.emit()
	)
