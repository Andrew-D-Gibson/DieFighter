class_name PiercingDamageHandler
extends EffectHandler
## DAMAGE (running amount) that skips the shields. See PiercingDamageEvent.


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return
	var event := PiercingDamageEvent.new()
	event.amount = context.running_amount
	_stamp(event, context)
	event.targets = context.targets.duplicate()
	engine.inject_event(event)
