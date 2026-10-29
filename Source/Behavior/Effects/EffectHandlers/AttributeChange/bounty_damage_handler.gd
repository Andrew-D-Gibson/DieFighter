class_name BountyDamageHandler
extends EffectHandler
## DAMAGE (running amount) that pays `amount` credits for each hostile
## warship the hit itself destroys. See BountyDamageEvent.


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return
	var event := BountyDamageEvent.new()
	event.amount = context.running_amount
	event.bounty = data.amount
	_stamp(event, context)
	event.targets = context.targets.duplicate()
	engine.inject_event(event)
