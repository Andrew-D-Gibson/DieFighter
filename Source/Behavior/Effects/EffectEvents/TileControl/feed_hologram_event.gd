class_name FeedHologramEvent
extends EffectEvent
## Spawns a holographic die at the source tile and Feeds it on.
##
## The Feed itself is a PassDieToTileEvent, so a hologram obeys the same rules
## as a real die: a tile that refuses it sends it to the target, and an enemy
## receiving a hologram destroys it.

## Feeds that carried the source tile's own die here, if it had one. The
## hologram leaves from the same point in the machine.
var feed_depth: int = 0


## amount is the hologram's face value, not an output to boost.
func is_amplifiable() -> bool:
	return false


func resolve(engine: ScenarioEngine) -> void:
	if amount <= 0 or not is_instance_valid(Globals.player):
		return
	if not is_instance_valid(effect_source) or effect_source is not Tile:
		return

	var source: Tile = effect_source as Tile
	var hologram: Dice = Globals.player.dice_scene.instantiate()
	hologram.holographic = true
	hologram.value = amount
	hologram.global_position = source.global_position
	# Every die lives under the player node, including the ones out on the grid.
	Globals.player.add_child(hologram)
	hologram.draggable.state = Draggable.DragState.MOVING_WITH_CODE

	# Code that animates a die asks which queue it belongs to, so give the
	# hologram the same history a placed die has: queued on this tile, then
	# taken back out as it activates.
	source.dice_queue.add(hologram, true, false)
	source.dice_queue.remove(hologram)

	var feed := PassDieToTileEvent.new()
	feed.actor = actor
	feed.effect_source = source
	feed.activator_die = hologram
	feed.die_value = amount
	feed.targets = targets.duplicate()
	feed.feed_depth = feed_depth
	engine.inject_event(feed)
