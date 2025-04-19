class_name TargetPlayerEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	effect_variables.targets = Array([Globals.player])
