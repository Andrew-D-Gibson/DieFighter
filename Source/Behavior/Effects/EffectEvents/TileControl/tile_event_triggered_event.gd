class_name TileEventTriggeredEvent
extends EffectEvent

## The tile whose event_responses chain is firing.
var responder: Tile

## The chain to play (already resolved to the matching TileEvent's response).
var chain: EffectChain


func resolve(engine: ScenarioEngine) -> void:
	if not is_instance_valid(responder):
		return

	var context: EffectContext = EffectContext.new()
	context.actor = Globals.player
	context.effect_source = responder

	await chain.play(context, engine)
