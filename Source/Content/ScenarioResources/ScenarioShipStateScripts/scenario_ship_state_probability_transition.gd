class_name ScenarioShipStateProbabilityTransition
extends ScenarioShipStateBase

@export var weighted_probabilities: Dictionary[ScenarioShipState, float]


func get_next_state_from_probabilities() -> ScenarioShipState:
	var probabilities: Array[float] = weighted_probabilities.values()
	
	# Sum the probabilities
	var prob_sum: float = 0
	for prob: float in probabilities:
		prob_sum += prob
		
	# Randomly choose a value between 0 and the sum, then 
	# grab the state that corresponds to that value
	var random_value: float = RNGManager.randf_range(RNGManager.Bucket.ENEMY_AI, 0, prob_sum)
	for state: ScenarioShipState in weighted_probabilities.keys():
		if random_value <= weighted_probabilities[state]:
			return state
		
		random_value -= weighted_probabilities[state]
	
	# Only reachable through float rounding leaving random_value a hair above
	# the last weight; fall back to any state rather than none.
	push_warning("Weighted scenario transition fell through; picking at random.")
	return RNGManager.pick_random(RNGManager.Bucket.ENEMY_AI, weighted_probabilities.keys())
		
	
