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

	# A reactive chain is often conditional ("if the engine is charged..."),
	# so the tile only lights up if the chain actually queued something.
	# Lighting up when nothing happened would teach the player to ignore it.
	var queued_before: int = engine.event_queue.size()
	await chain.play(context, engine)
	if is_instance_valid(responder) and engine.event_queue.size() > queued_before:
		responder.play_trigger_feedback(Globals.yellow)
