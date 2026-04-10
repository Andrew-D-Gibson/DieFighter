class_name AddUsesRemainingHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return

	var event := AddUsesRemainingEvent.new()
	event.actor    = context.actor
	event.targets  = context.targets.duplicate()
	event.amount   = data.amount
	engine.queue_event(event)
