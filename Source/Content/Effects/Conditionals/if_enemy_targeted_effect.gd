class_name IfEnemyTargetedEffect
extends Effect

@export var if_true_effect: Effect
@export var if_false_effect: Effect

func play(effect_variables: EffectVariables) -> void:
	if len(effect_variables.targets) > 0 and effect_variables.targets[0] is Enemy:
		await if_true_effect.play(effect_variables)
	else:
		await if_false_effect.play(effect_variables)
