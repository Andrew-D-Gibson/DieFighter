class_name AddUsesRemainingToTargetTilesEffect
extends Effect

@export var uses_to_add: int = 1

func play(effect_variables: EffectVariables) -> void:
	for target in effect_variables.targets:
		if target and\
		target is Tile:
			target.uses_remaining += uses_to_add
