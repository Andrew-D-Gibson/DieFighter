class_name StealMoneyHandler
extends EffectHandler

func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event: StealMoneyEvent = StealMoneyEvent.new()
	event.amount = context.running_amount
	_stamp(event, context)
	engine.inject_event(event)
