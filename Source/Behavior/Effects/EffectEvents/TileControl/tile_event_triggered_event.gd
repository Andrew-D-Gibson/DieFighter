class_name TileEventTriggeredEvent
extends EffectEvent

## The tile whose event_responses chain is firing.
var responder: Tile

## The chain to play (already resolved to the matching TileEvent's response).
var chain: EffectChain

## The ship the event happened to, when it was about one (a status landing on
## an enemy). The chain starts with it as its target, so "that ship" needs no
## targeting step. Null for events about nothing in particular.
var subject: Node = null


func resolve(engine: ScenarioEngine) -> void:
	if not is_instance_valid(responder):
		return

	var context: EffectContext = EffectContext.new()
	context.actor = Globals.player
	context.effect_source = responder
	if is_instance_valid(subject):
		context.targets = [subject] as Array[Node]

	# A reactive chain is often conditional ("if the engine is charged..."),
	# so the tile only lights up if the chain actually queued something.
	# Lighting up when nothing happened would teach the player to ignore it.
	var queued_before: int = engine.event_queue.size()
	await chain.play(context, engine)
	if is_instance_valid(responder) and engine.event_queue.size() > queued_before:
		responder.play_trigger_feedback(Globals.yellow)
