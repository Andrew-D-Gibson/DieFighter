class_name EnemyHealthBar
extends HealthBarController

func _get_health_string() -> String:
	return str(health_component.health)
	
