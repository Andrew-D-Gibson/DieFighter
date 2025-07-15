class_name FleeEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	if effect_variables.actor and effect_variables.actor is Enemy:
		Events.enemy_left.emit(effect_variables.actor, effect_variables.actor.scenario_state.faction)
		
		# Play the flee animation
		effect_variables.actor.queue_free()
