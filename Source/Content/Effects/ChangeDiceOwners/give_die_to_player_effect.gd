class_name GiveDieToPlayerEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	if not effect_variables.activator_die:
		printerr("GiveDieToPlayerEffect doesn't have an activator die!")
		return
	
	Globals.player.dice_manager.add(effect_variables.activator_die, true, false)
