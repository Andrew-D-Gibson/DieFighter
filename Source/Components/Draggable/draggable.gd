class_name Draggable
extends Area2D

signal drag_started()
signal drag_ended(draggable: Draggable, end_position: Vector2)

enum DragState {
	DEFAULT,
	ENEMY_HOLDING,
	MOVING_WITH_CODE,
	DRAGGING
}
var state: DragState = DragState.DEFAULT
static var dragging_an_object: bool = false


var follow_strength: float = 25
var home_position: Vector2

func _ready() -> void:
	if not home_position:
		home_position = global_position
		
		
func _process(delta: float) -> void:
	# Don't handle moving the draggable object if it's being moved with code
	if state == DragState.MOVING_WITH_CODE:
			return
						
	# Handle moving the object with the mouse
	if state == DragState.DRAGGING:
		get_parent().global_position = lerp(global_position, get_global_mouse_position(), follow_strength * delta)
		
		# Handle dropping this object if the mouse is no longer down
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			state = DragState.DEFAULT
			dragging_an_object = false
			
			# Move the parent's render index back to its original
			get_parent().z_index -= 3
			
			drag_ended.emit(self, get_global_mouse_position())
		return
		
	get_parent().global_position = lerp(global_position, home_position, follow_strength * delta)
	


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if state == DragState.DEFAULT and not dragging_an_object \
	and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		state = DragState.DRAGGING
		dragging_an_object = true
		
		# Move the parent's render index to be above where it usually sits
		get_parent().z_index += 3
		
		drag_started.emit()
