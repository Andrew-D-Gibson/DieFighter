class_name EffectChain
extends Resource

@export var effects: Array[Effect]

func play(effect_variables: EffectVariables) -> void:
	var die_starting_location: Vector2 = Vector2(0,0)
	if effect_variables.activator_die:
		die_starting_location = effect_variables.activator_die.global_position
		
	while effect_variables.repetitions > 0:
		effect_variables.repetitions -= 1
		
		if effect_variables.activator_die:
			effect_variables.activator_die.global_position = die_starting_location
			
		for effect: Effect in effects:
			await effect.play(effect_variables)
