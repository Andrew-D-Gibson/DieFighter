class_name AdvanceHorizonHandler
extends EffectHandler
## Reads the steps from context.running_amount.


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event: AdvanceHorizonEvent = AdvanceHorizonEvent.new()
	_stamp(event, context)
	event.amount = context.running_amount
	engine.inject_event(event)
