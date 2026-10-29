class_name HeldDieDelay
extends DelayedEffect
## A die a tile keeps past the end of the turn (HOLD_DIE_FOR_TURNS, the
## Holding Bay), handed back to the hand as a later turn starts.
##
## It comes back at the face it was held at. The hand is re-rolled before
## player_turn_start, and the die is still on the tile then, so it misses the
## re-roll: keeping a face for later is the point.
##
## While it waits it sits in the tile's queue, where the player can see it.
## It is still the player's (Player.dice_owned() counts it, and a jump brings
## it home like any die on a tile), but it isn't in hand, so it doesn't hold
## End Turn up. If the fight ends first, the tile lets it go with the rest of
## its dice (Tile.release_held_dice()); a jump carries it home.

## The die being kept.
var die: Dice = null


func _init(holder: Tile = null, held: Dice = null, turns: int = 1) -> void:
	modifier_name = "Held Die"
	source = holder
	affected_node = holder
	die = held
	turns_left = maxi(1, turns)


## The tile keeping the die.
func holder() -> Tile:
	return affected_node as Tile if is_instance_valid(affected_node) else null


func on_registered(engine: ScenarioEngine) -> void:
	super(engine)
	var tile: Tile = holder()
	if tile and is_instance_valid(die):
		tile.hold_over(die)


func get_info_text() -> String:
	if turns_left <= 1:
		return "[color=orange]Holding[/color] a die until your next turn."
	return "[color=orange]Holding[/color] a die for %d more turns." % turns_left


func _on_due(_engine_now: ScenarioEngine) -> void:
	var tile: Tile = holder()
	# Already gone home some other way (the tile was cleared, a jump).
	if not is_instance_valid(die) or die.is_queued_for_deletion() or tile == null \
	or die.host_queue != tile.dice_queue or not is_instance_valid(Globals.player):
		return
	Globals.player.dice_manager.add(die, true, false)
	die.draggable.state = Draggable.DragState.DEFAULT
	Juice.callout(tile, "RETURN", Globals.orange)
	tile.shakeable.small_shake()
