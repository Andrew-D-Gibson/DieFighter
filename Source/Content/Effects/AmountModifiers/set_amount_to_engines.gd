class_name SetAmountToEnginesEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	effect_variables.base_amount = Globals.player.engine_charge
