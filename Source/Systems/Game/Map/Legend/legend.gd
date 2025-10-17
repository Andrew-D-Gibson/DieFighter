class_name Legend
extends Sprite2D

@export var raised_y_delta: int = 0
@export var raise_speed: float = 12

@onready var original_location: Vector2 = global_position

var closed: bool = true
var movement_tween: Tween


func _ready() -> void:
	Events.map_shown.connect(_show_legend)
	Events.systems_shown.connect(_hide_legend)
	
	
func _show_legend() -> void:
	closed = false
	%ButtonSprite.flip_v = true
	_tween_to_position(original_location + Vector2(0, raised_y_delta))
		
		
func _hide_legend() -> void:
	closed = true
	%ButtonSprite.flip_v = false
	_tween_to_position(original_location)
		
		
func _tween_to_position(pos: Vector2) -> void:
	var distance_to_tween: int = abs(global_position.y - pos.y)
	var time_to_tween: float = distance_to_tween / raise_speed
	
	if movement_tween:
		movement_tween.kill()

	movement_tween = get_tree().create_tween()
	movement_tween.tween_property(
		self,
		"global_position",
		pos,
		time_to_tween
	).set_trans(Tween.TRANS_CUBIC)\
	.set_ease(Tween.EASE_IN_OUT)


func _on_button_pressed() -> void:
	if closed:
		_show_legend()
	else:
		_hide_legend()
