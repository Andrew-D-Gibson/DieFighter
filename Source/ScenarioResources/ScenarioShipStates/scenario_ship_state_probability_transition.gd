class_name ScenarioShipStateProbabilityTransition
extends ScenarioShipStateBase

@export var weighted_probabilities: Dictionary[ScenarioShipState, float]


func get_next_state_from_probabilities() -> ScenarioShipState:
	var probabilities: Array[float] = weighted_probabilities.values()
	
	# Sum the probabilities
	var prob_sum: float = 0
	for prob in probabilities:
		prob_sum += prob
		
	# Randomly choose a value between 0 and the sum, then 
	# grab the state that corresponds to that value
	var random_value: float = randf_range(0, prob_sum)
	for state in weighted_probabilities.keys():
		if random_value <= weighted_probabilities[state]:
			return state
		
		random_value -= weighted_probabilities[state]
	
	# This function will never return here, 
	# but to make the compiler happy:
	print('Your weighted scenario transition bonked genius')
	return weighted_probabilities.keys().pick_random()
		
	
