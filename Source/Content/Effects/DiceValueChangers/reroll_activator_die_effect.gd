class_name RerollActivatorDieEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	await effect_variables.activator_die.reroll_with_tween()
