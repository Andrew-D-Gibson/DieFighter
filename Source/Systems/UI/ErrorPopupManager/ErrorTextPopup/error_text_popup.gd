class_name ErrorTextPopup
extends RichTextLabel

@export_category('Behavior')
@export var full_opacity_time: float = 2
@export var fade_time: float = 1
@export var movement_velocity: Vector2 = Vector2(0, -0.5)

var _current_time_remaining: float 


func _ready() -> void:
	_current_time_remaining = full_opacity_time + fade_time
	

func _process(delta: float) -> void:
	_current_time_remaining -= delta
	
	position += movement_velocity *  delta
	
	if _current_time_remaining < fade_time:
		self.modulate = Color(1,1,1, _current_time_remaining / fade_time)
		
	if _current_time_remaining <= 0:
		queue_free()
