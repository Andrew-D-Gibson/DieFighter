class_name ShieldEffect
extends Effect

@export var amount: int = 0

func play(effect_variables: EffectVariables) -> void:
	# Don't do anything if there's no target
	if len(effect_variables.targets) == 0:
		return
		
	# If not given an amount (amount is 0),
	# use the activator die's value
	var _instance_amount: int = amount
	if amount == 0 and effect_variables.activator_die:
		_instance_amount = effect_variables.activator_die.value
	
	effect_variables.targets[0].health.change_shields(_instance_amount)
