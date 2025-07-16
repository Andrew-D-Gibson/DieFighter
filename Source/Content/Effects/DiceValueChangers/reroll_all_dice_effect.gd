class_name RerollAllDiceEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	var all_dice: Array[Node] = effect_variables.actor.get_tree().get_nodes_in_group('Dice')
	
	# Remove the activator dice
	all_dice.erase(effect_variables.activator_die)

	# Sort remaining dice by x, then y
	all_dice.sort_custom(func(a, b):
		var ax: float = a.global_position.x
		var bx: float = b.global_position.x
		if ax != bx:
			return ax < bx
		else:
			return a.global_position.y < b.global_position.y
	)

	# Prepend activator_die back
	all_dice.insert(0, effect_variables.activator_die)
	
	for die in all_dice:
		die.reroll_with_tween()
		await effect_variables.actor.get_tree().create_timer(0.15).timeout
