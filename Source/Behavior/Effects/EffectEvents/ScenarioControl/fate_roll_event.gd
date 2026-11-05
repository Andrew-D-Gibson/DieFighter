class_name FateRollEvent
extends EffectEvent
## The face Fate threw at the start of a Reckoning round, playing out: its
## FateFaceResource chain, with the player as actor and no die, queued behind
## whatever the turn start already set going.

var chain: EffectChain


func is_amplifiable() -> bool:
	return false


func resolve(engine: ScenarioEngine) -> void:
	if chain == null:
		return
	var context: EffectContext = EffectContext.new()
	context.actor = actor
	context.effect_source = effect_source
	await chain.play(context, engine)
