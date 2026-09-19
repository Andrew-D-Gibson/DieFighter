class_name PassDieToTileHandler
extends EffectHandler
## Passes the activator die to the first targeted tile, which then activates
## with it. Pair with TARGET_TILE_WITH_OFFSET to build a directional relay.
##
## Queues the event even with no target, because the die has to be disposed of
## either way — see PassDieToTileEvent._hand_die_off().
##
## Only fires on the final repetition; a chain that repeats shouldn't hand the
## die away halfway through its own work.


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.repetitions > 0:
		return

	if not is_instance_valid(context.activator_die):
		return

	var event := PassDieToTileEvent.new()
	event.actor         = context.actor
	event.effect_source = context.effect_source
	event.activator_die = context.activator_die
	event.targets       = context.targets.duplicate()
	engine.inject_event(event)
