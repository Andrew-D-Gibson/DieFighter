@tool
class_name Shakeable
extends Node2D

@export var node_to_shake: Node2D

@export_category('Shake Variables')
@export var small_shake_intensity: float = 1
@export var small_shake_duration: float = 0.1

@export var large_shake_intensity: float = 2
@export var large_shake_duration: float = 0.2


var original_position: Vector2
var shake_intensity: float
var shake_duration: float
var shake_time_remaining: float
var shaking: bool = false

signal shake_started()
signal shake_ended()

@export_tool_button("Small Shake", "Callable") var small_shake_action = small_shake
@export_tool_button("Large Shake", "Callable") var large_shake_action = large_shake


func _ready() -> void:
	if not node_to_shake:
		node_to_shake = get_parent()
	original_position = node_to_shake.position
		
		
func _process(delta: float) -> void:
	if not shaking or not node_to_shake:
		return
		
	if shake_time_remaining <= 0:
		shaking = false
		node_to_shake.position = original_position
		shake_ended.emit()
		return
		
	shake_time_remaining -= delta
	var shake_offset = _random_offset(shake_intensity)
	node_to_shake.position = node_to_shake.position.lerp(
		original_position + shake_offset,
		0.5
	)
	shake_intensity = lerp(shake_intensity, 0.0, delta / shake_duration)
	
	
		
func small_shake() -> void:
	shake_intensity = small_shake_intensity
	shake_time_remaining = small_shake_duration
	shake_duration = small_shake_duration
	_start_shake()


func large_shake() -> void:
	shake_intensity = large_shake_intensity
	shake_time_remaining = large_shake_duration
	shake_duration = large_shake_duration
	_start_shake()
	

func _start_shake() -> void:
	if shaking:
		node_to_shake.position = original_position

	original_position = node_to_shake.position
	shaking = true
	shake_started.emit()
	

func _random_offset(intensity: float) -> Vector2:
	return Vector2(
		randf_range(-intensity, intensity),
		randf_range(-intensity, intensity)
	)
