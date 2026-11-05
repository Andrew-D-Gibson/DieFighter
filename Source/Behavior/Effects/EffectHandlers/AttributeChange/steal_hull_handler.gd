class_name StealHullHandler
extends EffectHandler
## DAMAGE (running amount) that skips the shields and heals the actor by the
## hull it took. See StealHullEvent.


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return
	var event := StealHullEvent.new()
	event.amount = context.running_amount
	_stamp(event, context)
	event.targets = context.targets.duplicate()
	engine.inject_event(event)
