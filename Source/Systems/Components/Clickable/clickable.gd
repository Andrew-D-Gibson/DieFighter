class_name Clickable
extends Area2D

@export var click_movement_radius: float = 4
var click_down_location: Vector2

@export var click_time_window: float = 0.3
var click_time_remaining: float = 0

@export var hover_for_info: bool = true
@export var hover_delay: float = 0.5
var hover_time_elapsed: float = 0
var hovered: bool = false
var hover_delay_reached: bool = false

signal clicked()
signal is_hovered(hovered: bool)
signal hover_delay_completed()
signal hover_delay_reset()


func _process(delta: float) -> void:
	if hover_for_info and hovered and not hover_delay_reached:
		hover_time_elapsed += delta
		if hover_time_elapsed >= hover_delay:
			hover_delay_reached = true
			hover_delay_completed.emit()
			
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
	Events.set_current_clickable.emit(self)
	
	
func _on_mouse_exited() -> void:
	reset_hover_state()


func reset_hover_state() -> void:
	hovered = false
	hover_time_elapsed = 0
	hover_delay_reached = false
	is_hovered.emit(false)
	hover_delay_reset.emit()
	Events.set_current_clickable.emit(null)
