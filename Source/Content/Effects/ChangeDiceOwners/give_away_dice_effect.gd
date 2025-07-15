class_name GiveAwayDiceEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	if effect_variables.actor and effect_variables.actor is Enemy:
		effect_variables.actor.dice_manager.give_away_dice()
