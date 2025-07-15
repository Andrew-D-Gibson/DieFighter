class_name EffectChain
extends Resource

@export var effects: Array[Effect]

func play(effect_variables: EffectVariables) -> void:
	for effect in effects:
		await effect.play(effect_variables)
