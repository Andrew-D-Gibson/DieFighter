class_name CallAllyHandler
extends EffectHandler
## Reads how much an ally already aboard is healed and shielded from
## context.running_amount.


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event: CallAllyEvent = CallAllyEvent.new()
	_stamp(event, context)
	event.amount = context.running_amount
	engine.inject_event(event)
