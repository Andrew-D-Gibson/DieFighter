class_name AddUsesRemainingToTargetEffect
extends Effect

@export var uses_to_add: int = 1

func play(effect_variables: EffectVariables) -> void:
	if effect_variables.effect_source and\
	effect_variables.effect_source is Tile:
		effect_variables.effect_source.uses_remaining += uses_to_add
