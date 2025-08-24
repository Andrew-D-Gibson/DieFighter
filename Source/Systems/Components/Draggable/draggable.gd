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

@export var dragging_allowed: bool = true

var follow_strength: float = 20
var home_position: Vector2 :
	set(new_home):
		if home_position != new_home:
			emit_reached_new_home = true
		home_position = new_home
		
var emit_reached_new_home: bool = false
var tween: Tween

# --- Floating Behavior ---
@export var floating_enabled: bool = true:
	set(new_enabled_state):
		floating_enabled = new_enabled_state
		
		if not floating_enabled and get_parent():
			get_parent().rotation = 0
			
		if floating_enabled:
			_floating_time = randf() * TAU

# --- Adjustable floating parameters ---
@export var bob_amplitude: float = 4.0   # Max vertical movement in pixels
@export var bob_speed: float = 1.0       # How fast it bobs up and down
@export var drift_amplitude: float = 3.0 # Max horizontal drift in pixels
@export var drift_speed: float = 0.5     # How fast it drifts left/right
@export var rotation_amplitude: float = 3.0 # Max rotation in degrees
@export var rotation_speed: float = 0.3     # Rotation oscillation speed

# --- Internal floating variables ---
var _floating_time: float = 0.0
var _floating_start_pos: Vector2


func _ready() -> void:
	emit_reached_new_home = false
	if not home_position:
		home_position = global_position
	
	# Connect mouse enter/exit signals for hover scaling
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
		
		
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
			Globals.mouse_is_dragging_something = false
			
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
		if not floating_enabled:
			get_parent().global_position = home_position
		emit_reached_new_home = false
		
		reached_new_home.emit()
		
	if state == DragState.DEFAULT and global_position.distance_to(home_position) < 4 and floating_enabled:
		_floating_time += delta
	
		var bob_offset = sin(_floating_time * bob_speed) * bob_amplitude
		var drift_offset = sin(_floating_time * drift_speed + 1.5) * drift_amplitude
		var rot_offset = sin(_floating_time * rotation_speed + 0.8) * deg_to_rad(rotation_amplitude)

		#get_parent().rotation = rot_offset
		get_parent().global_position = lerp(global_position, home_position + Vector2(drift_offset, bob_offset), follow_strength * delta * 0.2)
	else:
		get_parent().global_position = lerp(global_position, home_position, follow_strength * delta)
	

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if dragging_allowed and state == DragState.DEFAULT and event is InputEventMouseButton \
	and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		state = DragState.DRAGGING
		Globals.mouse_is_dragging_something = true
		
		var parent_node: Node2D = get_parent()
		
		# Reset the info cursor if needed
		if parent_node.has_node("Clickable") and parent_node.clickable:
			parent_node.clickable.reset_hover_state()
		
		# Move the parent's render index to be above where it usually sits
		parent_node.z_index += 3
		parent_node.scale = Vector2(1.3,1.3)
		
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


func _on_mouse_entered() -> void:
	# Only scale on hover if not currently dragging
	if dragging_allowed and state == DragState.DEFAULT and not Globals.mouse_is_dragging_something:
		Events.play_sound.emit("hover_thump")
		
		var parent: Node = get_parent()
		if parent is Dice and parent.host_queue and parent.host_queue.get_parent() is Tile:
			return
			
		get_parent().scale = Vector2(1.15, 1.15)


func _on_mouse_exited() -> void:
	# Reset scale when mouse exits, but only if not dragging
	if state == DragState.DEFAULT:
		var parent: Node = get_parent()
		if parent is Dice and parent.host_queue and parent.host_queue.get_parent() is Tile:
			return
			
		get_parent().scale = Vector2(1, 1)


func snap_back() -> void:
	return
