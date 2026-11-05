extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
var popup_time: float = 2.25
## How big the icon swells as it fades. Set before the popup enters the tree.
var end_scale: Vector2 = Vector2(2, 2)

signal popup_finished()

func _ready() -> void:
	var adjusted_tween_time: float = popup_time / Globals.animation_speed
	
	# Bound to this node, so a scene change that frees the popup mid-tween
	# takes the callback with it instead of calling into a freed node.
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property($Sprite2D, "scale", end_scale, adjusted_tween_time).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Sprite2D, "modulate", Color(1,1,1,0.25), adjusted_tween_time)
	tween.chain().tween_callback(func() -> void:
		popup_finished.emit()
		queue_free()
	)
