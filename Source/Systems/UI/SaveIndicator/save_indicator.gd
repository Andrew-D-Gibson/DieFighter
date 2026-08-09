class_name SaveIndicator
extends Control

@export var full_opacity_time: float = 2.0
@export var fade_time: float = 2.0

var _tween: Tween


func _ready() -> void:
	modulate.a = 0.0
	visible = false
	Events.game_saved.connect(_on_game_saved)


func _on_game_saved() -> void:
	visible = true

	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	_tween.tween_interval(full_opacity_time)
	_tween.tween_property(self, "modulate:a", 0.0, fade_time)
	_tween.tween_callback(func() -> void: visible = false)
