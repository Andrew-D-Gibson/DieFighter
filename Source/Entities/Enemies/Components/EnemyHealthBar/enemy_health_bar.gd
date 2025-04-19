class_name EnemyHealthBar
extends HealthBarController

func _get_health_string() -> String:
	return str(health_component.health)
	

func set_attitude_indicator(attitude: Enemy.Attitude) -> void:
		match attitude:
			Enemy.Attitude.FRIENDLY:
				if $AttitudeIndicator.frame != 1:
					var tween_time: float = 0.5
					var tween = get_tree().create_tween()
					tween.tween_property($AttitudeIndicator, 'rotation_degrees', 360, tween_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
					tween.tween_property($AttitudeIndicator, 'scale', Vector2(1.4,1.4), tween_time * 0.2).set_trans(Tween.TRANS_QUAD)
					tween.tween_property($AttitudeIndicator, 'scale', Vector2(1.0,1.0), tween_time * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					
				$AttitudeIndicator.frame = 1
				
				
			Enemy.Attitude.NEUTRAL:
				if $AttitudeIndicator.frame != 2:
					var tween_time: float = 0.1
					var tween = get_tree().create_tween()
					tween.tween_property($AttitudeIndicator, 'rotation_degrees', 25, tween_time * 0.2).set_trans(Tween.TRANS_QUAD)
					tween.tween_property($AttitudeIndicator, 'rotation_degrees', 0, tween_time * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					
				$AttitudeIndicator.frame = 2
				
				
			Enemy.Attitude.AGGRESSIVE:
				if $AttitudeIndicator.frame != 3:
					var tween_time: float = 0.25
					var tween = get_tree().create_tween()
					tween.tween_property($AttitudeIndicator, 'scale', Vector2(2.0,2.0), tween_time * 0.2).set_trans(Tween.TRANS_QUAD)
					tween.tween_property($AttitudeIndicator, 'scale', Vector2(1.0,1.0), tween_time * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					
				$AttitudeIndicator.frame = 3
