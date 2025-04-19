class_name WaitForMillisecondsEffect
extends Effect

@export var milliseconds_to_wait: int

func play(effect_variables: EffectVariables) -> void:
	await effect_variables.actor.create_timer(milliseconds_to_wait / float(1000)).timeout
