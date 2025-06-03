class_name Flip1sAnd6sEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	for die in Globals.player.dice_manager.queue:
		if die.value == 1:
			die.reroll_with_tween(6)
		elif die.value == 6:
			die.reroll_with_tween(1)
			
