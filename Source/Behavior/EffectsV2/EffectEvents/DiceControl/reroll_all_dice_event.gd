class_name RerollAllDiceEvent
extends EffectEvent


func resolve(engine: ScenarioEngine) -> void:
	var all_dice: Array[Node] = engine.get_tree().get_nodes_in_group("Dice")

	# Move the activator die to the front so it rerolls first.
	if is_instance_valid(activator_die):
		all_dice.erase(activator_die)
		all_dice.sort_custom(func(a: Node, b: Node) -> bool:
			var ax: float = a.global_position.x
			var bx: float = b.global_position.x
			return ax < bx if ax != bx else a.global_position.y < b.global_position.y
		)
		all_dice.insert(0, activator_die)

	for die: Node in all_dice:
		if is_instance_valid(die):
			die.reroll_with_tween()
			await engine.get_tree().create_timer(0.2).timeout
