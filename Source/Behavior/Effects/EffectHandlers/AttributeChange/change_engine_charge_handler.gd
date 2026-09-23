class_name ChangeEngineChargeHandler
extends EffectHandler

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	# Instantiate a new event
	var event: ChangeEngineChargeEvent = ChangeEngineChargeEvent.new()

	# Read the amount from the running amount (set by prior AMOUNT_MODIFIER steps)
	event.amount = context.running_amount
			
	_stamp(event, context)

	engine.inject_event(event)
