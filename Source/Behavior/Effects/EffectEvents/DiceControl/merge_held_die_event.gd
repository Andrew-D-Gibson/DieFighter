class_name MergeHeldDieEvent
extends EffectEvent
## Welds the die a tile is holding into the activator die: the activator gains
## the held die's value, capped at 6 like every die. The held die going back
## to the player's hand is its own event (MergeHeldDieHandler queues it next),
## so a freeze that cancels the weld still sends it home.

## The die the tile was holding when the merge was queued.
var held_die: Node = null  # Type: Dice


## See EffectEvent.changes_die_values().
func changes_die_values() -> bool:
	return true


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die) or not is_instance_valid(held_die):
		return

	var combined: int = mini(activator_die.value + held_die.value, 6)
	await activator_die.reroll_with_tween(combined)
