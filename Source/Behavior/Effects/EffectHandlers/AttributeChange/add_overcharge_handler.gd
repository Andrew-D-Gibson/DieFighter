class_name AddOverchargeHandler
extends EffectHandler
## Pushes charge into the redline band.
##
## Builds the same ChangeEngineChargeEvent as an ordinary charge gain, only
## with allow_overcharge set, so EngineBlackoutModifier still cancels it and
## AmountCapModifier still caps it — a blackout region should stop a player
## redlining just as surely as it stops them charging.


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event: ChangeEngineChargeEvent = ChangeEngineChargeEvent.new()
	event.amount = context.running_amount
	event.allow_overcharge = true

	_stamp(event, context)

	engine.inject_event(event)
