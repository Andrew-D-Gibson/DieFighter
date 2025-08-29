class_name SpawnHolographicDiceEffect
extends Effect

@export var amount: int = 0

func play(effect_variables: EffectVariables) -> void:
	effect_variables.base_amount = amount
	var final_amount: int = effect_variables.calculate_final_amount()
	
	Globals.player.spawn_dice(final_amount, effect_variables.activator_die.value, true)
