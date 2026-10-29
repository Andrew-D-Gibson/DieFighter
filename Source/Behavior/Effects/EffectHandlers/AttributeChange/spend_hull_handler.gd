class_name SpendHullHandler
extends EffectHandler
## Spends the player's hull as a cost (SpendHullEvent).
##
## The cost is data.amount when authored, falling back to
## context.running_amount, as SPEND_SHIELDS does. Either way it is a positive
## number; the event turns it into a subtraction.


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event: SpendHullEvent = SpendHullEvent.new()
	event.amount = data.amount if data.amount != 0 else context.running_amount

	_stamp(event, context)

	engine.inject_event(event)
