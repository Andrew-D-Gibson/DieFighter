class_name ActivateTargetedTilesHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return

	var event := ActivateTargetedTilesEvent.new()
	event.actor         = context.actor
	event.effect_source = context.effect_source
	event.activator_die = context.activator_die
	event.targets       = context.targets.duplicate()
	engine.queue_event(event)
