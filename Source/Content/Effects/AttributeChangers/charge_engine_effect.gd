class_name ChargeEngineEffect
extends Effect

@export var amount: int = 0
@export var inherit_die_amount: bool = false

func play(effect_variables: EffectVariables) -> void:
	# Set base damage
	if inherit_die_amount and effect_variables.activator_die:
		effect_variables.base_amount = effect_variables.activator_die.value
	elif amount != 0:
		effect_variables.base_amount = amount
	
	# Calculate final damage after all modifiers
	var final_amount = effect_variables.calculate_final_amount()

	Globals.player.engine_charge += final_amount

	# Clear modifiers
	effect_variables.clear_amount_modifiers()
