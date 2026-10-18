@tool
extends Node2D
## Drives the accretion disk's swirl. The disk shader reads time from a
## uniform rather than TIME, so the animation runs in the editor too.

var _time: float = 1000.0


func _process(delta: float) -> void:
	_time += delta
	$Disk.material.set_shader_parameter("time", _time * 314.15 * 0.004)
