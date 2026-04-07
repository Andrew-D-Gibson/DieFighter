## EffectChainV2
## ============================================================
## The v2 replacement for EffectChain.
##
## Instead of holding Array[Effect] (where each Effect mutates state),
## this holds Array[EffectData] — pure data describing intent.
## Each entry is processed by the appropriate EffectHandler, which
## either modifies the context (targeting) or enqueues events (combat/visual).
##
## DIFFERENCES FROM OLD EffectChain:
##   - Effects no longer mutate state directly.
##   - Repetitions are still supported (same die-reset logic as before).
##   - The caller must await engine.process_events() after calling play()
##     to ensure all enqueued events actually resolve.
##
## AUTHORING:
##   1. Create a new resource of type EffectChainV2.
##   2. Add EffectData entries to the 'effects' array.
##      Order matters — entries execute top to bottom.
##   3. Assign it to TileResource.effect_chain_v2.
##
## TYPICAL USAGE IN Tile.activate():
##   var context := EffectContext.new()
##   context.actor = Globals.player
##   context.effect_source = self
##   context.activator_die = activator_die
##   await tile_resource.effect_chain_v2.play(context, scenario_engine)
##   await scenario_engine.process_events()
##
## NOTE: play() is async because handlers can await animations (tweens, etc.).
## ============================================================

class_name EffectChainV2
extends Resource


## The ordered list of effects in this chain.
## Each entry is processed in sequence for each repetition.
@export var effects: Array[EffectData] = []


## Execute the chain for the given context and engine.
## Handles repetitions identically to the old EffectChain:
##   - Records the die's starting position before the first loop.
##   - Resets the die position at the start of each repetition.
##   - Decrements context.repetitions each loop.
func play(context: EffectContext, engine: ScenarioEngine) -> void:
	# Cache the die's start position so each repetition begins identically.
	var die_start_position: Vector2 = Vector2.ZERO
	if context.activator_die:
		die_start_position = context.activator_die.global_position

	while context.repetitions > 0:
		context.repetitions -= 1

		# Reset die position for this repetition.
		if context.activator_die:
			context.activator_die.global_position = die_start_position

		# Execute each effect in order.
		for data: EffectData in effects:
			var handler: EffectHandler = EffectRegistry.get_handler(data.category, data.subtype)
			if handler == null:
				push_error(
					"EffectChainV2: no handler for category=%d subtype=%d" % [data.category, data.subtype]
				)
				continue
			await handler.apply(data, context, engine)
