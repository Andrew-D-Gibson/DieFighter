class_name GiveDiceToPlayerEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	for i: int in range(len(effect_variables.actor.dice_manager.queue)-1, -1, -1):
		Globals.player.dice_manager.add(effect_variables.actor.dice_manager.queue[i])
