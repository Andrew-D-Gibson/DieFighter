class_name PlayerHealthBar
extends HealthBarController

func _set_shields() -> void:		
	super()
	if health_component.shields < health_component.max_health / 2.0:
		%Shields.frame = 2
	elif health_component.shields < health_component.max_health:
		%Shields.frame = 1
	else:\
		%Shields.frame = 0


func _get_health_string() -> String:
	return "[wave amp=2.0 freq=1.0 connected=0]HULL\n" + \
	str(health_component.health) + '/' + \
	str(health_component.max_health) + \
	"[/wave]"


func _get_shield_string() -> String:
	return "[wave amp=2.0 freq=1.0 connected=0]" + \
	str(health_component.shields) + \
	"[/wave]"
