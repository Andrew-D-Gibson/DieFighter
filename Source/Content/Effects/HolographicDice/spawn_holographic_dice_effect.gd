class_name SpawnHolographicDiceEffect
extends Effect

@export var amount: int = 0

func play(effect_variables: EffectVariables) -> void:
	Globals.player.spawn_dice(amount, effect_variables.activator_die.value, true)
