class_name DelayedPayloadEvent
extends EffectEvent
## A DelayedPayload going off: plays its steps against the ship it is planted
## on, with the running amount it was armed with, through the engine's usual
## order and modifiers.
##
## The steps run on one context with no repetition loop and no die, like a
## conditional's branch: EffectChain.play() would zero the running amount
## before the first step, and the amount is the whole point.

var effects: Array[EffectData] = []


func resolve(engine: ScenarioEngine) -> void:
	if targets.is_empty() or not is_instance_valid(targets[0]):
		return

	var context := EffectContext.new()
	context.actor = actor
	context.effect_source = effect_source
	context.targets = targets.duplicate()
	context.running_amount = amount
	context.repetitions = 0

	for data: EffectData in effects:
		if data == null:
			continue
		var handler: EffectHandler = EffectRegistry.get_handler(data.category, data.subtype)
		if handler == null:
			continue
		await handler.apply(data, context, engine)


## Its amount was fixed when it was armed; the hit it queues is what modifiers
## act on.
func is_amplifiable() -> bool:
	return false
