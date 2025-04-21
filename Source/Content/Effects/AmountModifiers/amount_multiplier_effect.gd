class_name AmountMultiplierEffect
extends Effect

@export var multiplier: float = 1.0

func play(effect_variables: EffectVariables) -> void:
	effect_variables.add_amount_modifier(func(amount: int) -> int:
		return int(amount * multiplier)
	) 
