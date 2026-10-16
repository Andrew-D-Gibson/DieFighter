class_name SpendShieldsHandler
extends EffectHandler
## Spends the player's shields as a cost.
##
## The cost is data.amount when authored, falling back to context.running_amount
## so a variable price composes (SET_TO_TARGET_SHIELDS -> SPEND_SHIELDS spends
## them all). Either way it is a positive number; the event turns it into a
## subtraction.


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event: SpendShieldsEvent = SpendShieldsEvent.new()
	event.amount = data.amount if data.amount != 0 else context.running_amount

	_stamp(event, context)

	engine.inject_event(event)
