class_name PrintIfTileAffectedEffect
extends Effect

@export var string: String

func play(effect_variables: EffectVariables) -> void:
	if not effect_variables.effect_source:
		return
		
	if len(effect_variables.targets) <= 0:
		return
		
	if effect_variables.effect_source == effect_variables.targets[0]:
		print(string)
