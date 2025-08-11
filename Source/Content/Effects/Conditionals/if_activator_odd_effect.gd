class_name IfActivatorOddEffect
extends Effect

@export var if_true_effect: Effect
@export var if_false_effect: Effect

func play(effect_variables: EffectVariables) -> void:
	if not effect_variables.activator_die:
		printerr("IfActivatorOddEffect doesn't have an activator die to check!")
		return
		
	if effect_variables.activator_die.value % 2 == 1:
		await if_true_effect.play(effect_variables)
	else:
		await if_false_effect.play(effect_variables)
