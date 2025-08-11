class_name IfEngineChargedEffect
extends Effect

@export var if_true_effect: Effect
@export var if_false_effect: Effect

func play(effect_variables: EffectVariables) -> void:		
	if Globals.player.engine_charge >= Globals.player.max_engine_charge:
		await if_true_effect.play(effect_variables)
	else:
		await if_false_effect.play(effect_variables)
