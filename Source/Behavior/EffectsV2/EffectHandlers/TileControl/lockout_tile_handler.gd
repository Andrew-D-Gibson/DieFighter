class_name LockoutTileHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return

	var event := LockoutTileEvent.new()
	event.actor    = context.actor
	event.targets  = context.targets.duplicate()
	engine.queue_event(event)
