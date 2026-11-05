class_name AdvanceShipMechanismEvent
extends EffectEvent
## Steps the flown ship's mechanism (ShipRules.mechanism()) by [member amount],
## signed, and holds the queue until the move has landed, so whatever resolves
## next reads the board as it now stands. Nothing on a ship without one.
##
## It moves tiles, not dice: a Flash Freeze leaves it alone
## (changes_die_values() stays false). The die that drove it rides along with
## its tile if the move carried the tile off, so it leaves from where the tile
## now is.

const _CATCH_UP_SECONDS: float = 0.12


func resolve(_engine: ScenarioEngine) -> void:
	if amount == 0:
		return
	var mechanism: Node = ShipRules.mechanism()
	if mechanism == null:
		return
	var tile: Tile = effect_source as Tile if is_instance_valid(effect_source) else null
	var die: Dice = activator_die as Dice if is_instance_valid(activator_die) else null
	var offset: Vector2 = die.global_position - tile.global_position if tile and die else Vector2.ZERO
	await mechanism.advance_mechanism(amount)
	if is_instance_valid(tile) and is_instance_valid(die) and die.is_inside_tree() \
	and not die.global_position.is_equal_approx(tile.global_position + offset):
		# Tree-owned, so a die freed mid-flight can't stall the queue.
		var tween: Tween = die.get_tree().create_tween()
		tween.tween_property(die, "global_position", tile.global_position + offset,
			_CATCH_UP_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tween.finished


## The amount is a number of steps: an Amplifier doesn't turn the ring further.
func is_amplifiable() -> bool:
	return false
