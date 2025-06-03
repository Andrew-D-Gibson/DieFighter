class_name NegativeAmountEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	effect_variables.base_amount *= -1
