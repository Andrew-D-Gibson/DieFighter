class_name FlipOnesAndSixesEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(Globals.player):
		return
	for die: Node in Globals.player.dice_manager.queue:
		if not is_instance_valid(die):
			continue
		if die.value == 1:
			die.reroll_with_tween(6)
		elif die.value == 6:
			die.reroll_with_tween(1)
