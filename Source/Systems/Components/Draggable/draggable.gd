class_name Draggable
extends Area2D

signal drag_started()
signal drag_ended(draggable: Draggable, end_position: Vector2)
signal reached_new_home()

enum DragState {
	DEFAULT,
	ENEMY_HOLDING,
	MOVING_WITH_CODE,
	DRAGGING
}
var state: DragState = DragState.DEFAULT

var follow_strength: float = 20
var home_position: Vector2 :
	set(new_home):
		if home_position != new_home:
			emit_reached_new_home = true
		home_position = new_home
		
var emit_reached_new_home: bool = false
var tween: Tween


func _ready() -> void:
	emit_reached_new_home = false
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
			
			var parent_node: Node2D = get_parent()
			
			# Stop the wiggle tween
			if tween:
				tween.kill()
			parent_node.rotation_degrees = 0

			# Move the parent's render index back to its original
			parent_node.z_index -= 3
			parent_node.scale = Vector2(1, 1)
			
			drag_ended.emit(self, get_global_mouse_position())
		return
	
	if emit_reached_new_home \
	and state == DragState.DEFAULT \
	and get_parent().global_position.distance_to(home_position) < 0.75:
		get_parent().global_position = home_position
		emit_reached_new_home = false
		reached_new_home.emit()
	
	get_parent().global_position = lerp(global_position, home_position, follow_strength * delta)
	


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if state == DragState.DEFAULT and event is InputEventMouseButton \
	and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		state = DragState.DRAGGING
		
		var parent_node: Node2D = get_parent()
		
		# Move the parent's render index to be above where it usually sits
		parent_node.z_index += 3
		parent_node.scale = Vector2(1.25,1.25)
		
		# Set the parent to wiggle a bit
		parent_node.rotation_degrees = 0
		if tween:
			tween.kill()
		var tween_time: float = 0.5
		tween = get_tree().create_tween()
		tween.tween_property(parent_node, "global_rotation_degrees", 3, tween_time).set_trans(Tween.TRANS_SINE)
		tween.tween_property(parent_node, "global_rotation_degrees", 0, tween_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_interval(tween_time)
		tween.tween_property(parent_node, "global_rotation_degrees", -3, tween_time).set_trans(Tween.TRANS_SINE)
		tween.tween_property(parent_node, "global_rotation_degrees", 0, tween_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_interval(tween_time)
		tween.set_loops()
		
		drag_started.emit()
