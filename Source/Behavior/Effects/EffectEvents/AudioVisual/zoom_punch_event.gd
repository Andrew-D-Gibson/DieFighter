class_name ZoomPunchEvent
extends EffectEvent

var peak_zoom: float = 1.0


func resolve(_engine: ScenarioEngine) -> void:
	var focus: Vector2 = Vector2.ZERO
	var has_focus: bool = false
	for target: Node in targets:
		if is_instance_valid(target) and target is Node2D:
			focus = (target as Node2D).global_position
			has_focus = true
			break

	Events.camera_zoom_punch.emit(peak_zoom, focus, has_focus)
