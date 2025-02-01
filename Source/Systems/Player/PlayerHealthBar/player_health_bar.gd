class_name PlayerHealthBar
extends HealthBarController

func _set_shields() -> void:		
	super()
	if health_component.shields < health_component.max_health / 2.0:
		$Shields.frame = 2
	elif health_component.shields < health_component.max_health:
		$Shields.frame = 1
	else:
		$Shields.frame = 0
