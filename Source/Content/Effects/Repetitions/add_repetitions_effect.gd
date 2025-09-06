class_name AddRepetitionsEffect
extends Effect

@export var repititions_to_add: int = 1
@export var times_this_can_activate: int = 1
var num_of_activations: int = 0

func play(effect_variables: EffectVariables) -> void:
	if num_of_activations >= times_this_can_activate:
		num_of_activations = 0
		return
		
	num_of_activations += 1
	
	var final_amount: int = repititions_to_add
	
	if primary_effect:
		effect_variables.base_amount = repititions_to_add
		final_amount = effect_variables.calculate_final_amount()
		
	effect_variables.repetitions += final_amount
