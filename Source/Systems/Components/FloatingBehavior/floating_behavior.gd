class_name FloatingBehavior
extends Node

@export var target_node_path: NodePath
@export var enabled: bool = true:
	set(new_enabled_state):
		enabled = new_enabled_state
		
		if not enabled and _target_node:
			_target_node.rotation = 0
			
		if enabled:
			_start_floating()
		

# --- Adjustable parameters ---
@export var bob_amplitude: float = 4.0   # Max vertical movement in pixels
@export var bob_speed: float = 1.0       # How fast it bobs up and down
@export var drift_amplitude: float = 3.0 # Max horizontal drift in pixels
@export var drift_speed: float = 0.5     # How fast it drifts left/right
@export var rotation_amplitude: float = 3.0 # Max rotation in degrees
@export var rotation_speed: float = 0.3     # Rotation oscillation speed

# --- Internal ---
var _time: float = 0.0
var _start_pos: Vector2
var _target_node: Node2D


func _start_floating() -> void:
	# If no node path is assigned, use parent
	if target_node_path == NodePath(""):
		_target_node = get_parent() as Node2D
	else:
		_target_node = get_node_or_null(target_node_path) as Node2D
	
	if _target_node == null:
		push_warning("Bobbing script: target node not found or is not a Node2D.")
		set_process(false)
		return
		
	if _target_node.has_node("Draggable"):
		_target_node.draggable.drag_started.connect(func() -> void:
			enabled = false	
		)
	
	# Store starting position and randomize motion phase
	_start_pos = _target_node.position
	_time = randf() * TAU


func _process(delta: float) -> void:
	if not enabled or _target_node == null:
		return
	
	_time += delta
	
	var bob_offset = sin(_time * bob_speed) * bob_amplitude
	var drift_offset = sin(_time * drift_speed + 1.5) * drift_amplitude
	var rot_offset = sin(_time * rotation_speed + 0.8) * deg_to_rad(rotation_amplitude)
	
	_target_node.position = _start_pos + Vector2(drift_offset, bob_offset)
	_target_node.rotation = rot_offset
