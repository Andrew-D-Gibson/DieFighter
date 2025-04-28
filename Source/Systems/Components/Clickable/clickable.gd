class_name Clickable
extends Area2D

@export var click_movement_radius: float = 4
var click_down_location: Vector2

@export var click_time_window: float = 0.3
var click_time_remaining: float = 0

var hovered: bool = false

signal clicked()
signal is_hovered(_hovered: bool)


func _process(delta: float) -> void:
	if click_time_remaining <= 0:
		return
	
	click_time_remaining -= delta
	

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			click_time_remaining = click_time_window
			click_down_location = get_global_mouse_position()
			
		elif click_time_remaining > 0 \
		and click_down_location.distance_to(get_global_mouse_position()) <= click_movement_radius:
			clicked.emit()


func _on_mouse_entered() -> void:
	hovered = true
	is_hovered.emit(true)
	
	
func _on_mouse_exited() -> void:
	hovered = false
	is_hovered.emit(false)
