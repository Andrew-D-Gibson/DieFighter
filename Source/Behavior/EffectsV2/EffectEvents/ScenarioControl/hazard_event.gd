class_name HazardEvent
extends EffectEvent
## Wraps a scenario hazard's chain so it resolves in the engine's normal order
## rather than jumping the queue.
##
## Hazards have no activator die — they're the environment acting, not a ship —
## so any chain assigned to one must avoid die-dependent effects.

## The hazard chain to play.
var chain: EffectChainV2


func resolve(engine: ScenarioEngine) -> void:
	if chain == null:
		return

	var context: EffectContext = EffectContext.new()
	context.actor = actor
	context.effect_source = effect_source

	await chain.play(context, engine)
