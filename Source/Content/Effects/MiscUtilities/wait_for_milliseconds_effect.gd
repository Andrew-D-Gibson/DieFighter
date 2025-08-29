class_name WaitForMillisecondsEffect
extends Effect

@export var milliseconds_to_wait: int

func play(effect_variables: EffectVariables) -> void:
	var timer: Timer = Timer.new()
	timer.wait_time = milliseconds_to_wait / float(1000)
	timer.autostart = true
	
	effect_variables.actor.add_child(timer)
	await timer.timeout
