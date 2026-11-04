class_name TileEventTriggeredEvent
extends EffectEvent

## The tile whose event_responses chain is firing.
var responder: Tile

## The chain to play (already resolved to the matching TileEvent's response).
var chain: EffectChain

## The ship the event happened to, when it was about one (a status landing on
## an enemy, the enemy that attacked the player). The chain starts with it as
## its target, so "that ship" needs no targeting step. Null for events about
## nothing in particular.
var subject: Node = null

## The EventType that triggered this event response, or -1 if unspecified.
var event_type: int = -1


func resolve(engine: ScenarioEngine) -> void:
	if not is_instance_valid(responder):
		return

	var context: EffectContext = EffectContext.new()
	context.actor = Globals.player
	context.effect_source = responder
	if still_in_fight(subject):
		context.targets = [subject] as Array[Node]

	# A reactive chain is often conditional ("if the engine is charged..."),
	# so the tile only lights up if the chain actually queued something.
	# Lighting up when nothing happened would teach the player to ignore it.
	# Combat-start housekeeping resets (ON_COMBAT_START) stay silent.
	var queued_before: int = engine.event_queue.size()
	await chain.play(context, engine)
	if is_instance_valid(responder) and engine.event_queue.size() > queued_before:
		if event_type != TileEvent.EventType.ON_COMBAT_START:
			responder.play_trigger_feedback(Globals.yellow)


## Whether [param ship] is still there to aim at. A response waits in the
## queue behind the chain that set it off, so by the time it plays the ship
## may have been destroyed or fled; then it starts with no target at all
## rather than hitting a wreck or a ship already on its way out.
##
## Untyped, because the ship may already be freed: GDScript refuses to pass a
## freed object to a Node parameter at all, so a typed check never gets to run.
static func still_in_fight(subject: Variant) -> bool:
	if not is_instance_valid(subject) or subject is not Node:
		return false
	var ship: Node = subject as Node
	if ship.is_queued_for_deletion():
		return false
	var health: Health = ship.get("health") as Health
	if health != null and (health.is_dead or health.health <= 0):
		return false
	if ship is Enemy and is_instance_valid(Globals.enemy_manager):
		return ship in Globals.enemy_manager.get_alive_enemies()
	return true
