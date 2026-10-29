class_name DelayEffectsHandler
extends EffectHandler
## Plants a DelayedEffectData's payload on the first target, to play on a
## later turn (see DelayedPayload). The running amount and the target are
## captured now; the steps run then.
##
## One per pass: an echoed tile plants two, as it would deal its damage twice.


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var delayed: DelayedEffectData = data as DelayedEffectData
	if delayed == null:
		push_error("DelayEffectsHandler: DELAY_EFFECTS needs a DelayedEffectData resource.")
		return
	if context.targets.is_empty() or not is_instance_valid(context.targets[0]):
		return

	var event := ArmDelayedPayloadEvent.new()
	_stamp(event, context)
	event.targets = [context.targets[0]]
	event.amount = context.running_amount
	event.payload = delayed
	engine.inject_event(event)
