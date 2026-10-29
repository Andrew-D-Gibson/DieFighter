class_name SplitActivatorEvent
extends EffectEvent
## Splits the activator die into two dice that add up to it (Die Splitter).
## The die keeps the bigger half, rounded up like every half in the game, and
## a hologram showing the rest joins the player's hand: 5 is 3 + 2, 6 is 3 + 3.
##
## The second die is a hologram, not a real one, so a split lasts until the
## hologram is spent instead of adding a die to the Fleet for the rest of the
## run. Both halves are one event, so a freeze that holds the die's face
## (DiceFreezeModifier) cancels the hologram with it rather than minting a
## free die.


## There is no amount: the die's face decides both halves.
func is_amplifiable() -> bool:
	return false


## See EffectEvent.changes_die_values().
func changes_die_values() -> bool:
	return true


## The two faces [param face] splits into: x is what the die keeps, y the
## hologram's. A 1 can't split, so its hologram face is 0.
static func halves(face: int) -> Vector2i:
	var kept: int = ceili(face / 2.0)
	return Vector2i(kept, face - kept)


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die) or not is_instance_valid(Globals.player):
		return

	var parts: Vector2i = halves(activator_die.value)
	if parts.y <= 0:
		return
	if is_instance_valid(effect_source) and effect_source is Node2D:
		var anchor: Node2D = effect_source as Node2D
		Juice.callout_at(anchor, Juice.anchor_of(anchor), "%d + %d" % [parts.x, parts.y], Globals.green)
	Globals.player.spawn_dice(1, parts.y, true)
	await activator_die.reroll_with_tween(parts.x)
