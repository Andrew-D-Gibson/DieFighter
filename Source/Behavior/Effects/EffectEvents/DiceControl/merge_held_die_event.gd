class_name MergeHeldDieEvent
extends EffectEvent
## Welds the die a tile is holding into the activator die: the activator gains
## the held die's value, capped at 6 like every die, and the held die goes back
## to the player's hand.


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die):
		return
	if not is_instance_valid(effect_source) or effect_source is not Tile:
		return

	var held: Dice = (effect_source as Tile).get_held_die(activator_die)
	if held == null:
		return

	var combined: int = mini(activator_die.value + held.value, 6)
	if is_instance_valid(Globals.player):
		Globals.player.dice_manager.add(held, true, false)
	await activator_die.reroll_with_tween(combined)
