class_name EnemyHealthBar
extends HealthBarController


## Single tween for manipulating the attitude indicator
## Used to animate the indicator on transitions for better clarity
var attitude_indicator_tween: Tween


## Changes the frame of the attitude indicator depending on the attitude
## Starts the necessary transition tween for player feedback
func set_attitude_indicator(attitude: Enemy.Attitude) -> void:
		match attitude:
			Enemy.Attitude.FRIENDLY:
				if $AttitudeIndicator.frame != 1:
					_handle_running_tween()
					$AttitudeIndicator.frame = 1
				
					_start_friendly_tween()
					
				
			Enemy.Attitude.NEUTRAL:
				if $AttitudeIndicator.frame != 2:
					_handle_running_tween()
					$AttitudeIndicator.frame = 2
					
					_start_neutral_tween()
				
				
			Enemy.Attitude.AGGRESSIVE:
				if $AttitudeIndicator.frame != 3:
					_handle_running_tween()
					$AttitudeIndicator.frame = 3
					
					_start_aggressive_tween()


## Resets the modified attributes of the attitude indicator
## This allows us to interrupt a running tween and start a new one
func _handle_running_tween() -> void:
	if attitude_indicator_tween:
		attitude_indicator_tween.kill()
		$AttitudeIndicator.scale = Vector2(1,1)
		$AttitudeIndicator.rotation_degrees = 0
		

## Spins the attitude indicator once, then a small 'pop' of the scale
func _start_friendly_tween() -> void:
	var tween_time: float = 0.5
	attitude_indicator_tween = get_tree().create_tween()
	
	attitude_indicator_tween.tween_property(
		$AttitudeIndicator, 
		'rotation_degrees', 
		360, 
		tween_time
	)\
	.set_trans(Tween.TRANS_BACK)\
	.set_ease(Tween.EASE_IN_OUT)
	
	attitude_indicator_tween.tween_property(
		$AttitudeIndicator, 
		'scale', 
		Vector2(1.4,1.4), 
		tween_time * 0.2
	)\
	.set_trans(Tween.TRANS_QUAD)
	
	attitude_indicator_tween.tween_property(
		$AttitudeIndicator, 
		'scale', 
		Vector2(1.0,1.0), 
		tween_time * 0.8
	)\
	.set_trans(Tween.TRANS_QUAD)\
	.set_ease(Tween.EASE_OUT)
	

## A very short rotational 'click' of the attitude indicator
func _start_neutral_tween() -> void:
	var tween_time: float = 0.1
	attitude_indicator_tween = get_tree().create_tween()
	
	attitude_indicator_tween.tween_property(
		$AttitudeIndicator, 
		'rotation_degrees', 
		25, 
		tween_time * 0.2
	)\
	.set_trans(Tween.TRANS_QUAD)
	
	attitude_indicator_tween.tween_property(
		$AttitudeIndicator, 
		'rotation_degrees', 
		0, 
		tween_time * 0.8
	)\
	.set_trans(Tween.TRANS_QUAD)\
	.set_ease(Tween.EASE_OUT)


## A quick 'pop' of the attitude indicator
func _start_aggressive_tween() -> void:
	var tween_time: float = 0.25
	attitude_indicator_tween = get_tree().create_tween()
	
	# Quickly double the scale to 'pop' the indicator
	attitude_indicator_tween.tween_property(
		$AttitudeIndicator, 
		'scale', 
		Vector2(2.0,2.0), 
		tween_time * 0.2
	)\
	.set_trans(Tween.TRANS_QUAD)
		
	# Reset the scale slowly
	attitude_indicator_tween.tween_property(
		$AttitudeIndicator, 
		'scale', 
		Vector2(1.0,1.0), 
		tween_time * 0.8
	)\
	.set_trans(Tween.TRANS_QUAD)\
	.set_ease(Tween.EASE_OUT)


## Formatter for how we display the enemy's health via text
## Overrides a function in the parent 'HealthBarController'
func _get_health_string() -> String:
	return str(health_component.health)
