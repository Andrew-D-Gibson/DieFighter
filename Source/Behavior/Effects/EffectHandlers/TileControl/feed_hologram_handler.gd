class_name FeedHologramHandler
extends EffectHandler
## Feeds a new holographic die, showing context.running_amount, to the first
## targeted tile. Pair with TARGET_TILE_WITH_OFFSET, like PASS_DIE_TO_TILE.
##
## Queues the event even with no target: the hologram is still spawned and
## handed to the enemy, which destroys it — the same outcome a refused real die
## gets, so a tile with nothing next to it behaves consistently.


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event := FeedHologramEvent.new()
	_stamp(event, context)
	event.amount     = context.running_amount
	event.targets    = context.targets.duplicate()
	event.feed_depth = context.feed_depth
	engine.inject_event(event)
