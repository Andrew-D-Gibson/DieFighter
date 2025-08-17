class_name HandOptionUnlockEffect
extends Effect

@export_range(1,6) var option_to_unlock: int = 1

func play(effect_variables: EffectVariables) -> void:
	Events.hand_option_unlock.emit(option_to_unlock)
