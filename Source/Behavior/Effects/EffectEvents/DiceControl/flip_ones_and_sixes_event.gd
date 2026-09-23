class_name FlipOnesAndSixesEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(actor):
		return
	
	var all_dice: Array[Node] = actor.get_tree().get_nodes_in_group('Dice')

	for die: Node in all_dice:
		if not is_instance_valid(die):
			continue
		if die.value == 1:
			die.reroll_with_tween(6)
		elif die.value == 6:
			die.reroll_with_tween(1)
