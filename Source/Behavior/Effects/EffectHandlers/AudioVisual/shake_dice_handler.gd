class_name ShakeDiceHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.activator_die):
		return

	var event := ShakeDiceEvent.new()
	_stamp(event, context)
	if data.amount > 0:
		event.duration_seconds = data.amount / 1000.0
	engine.inject_event(event)
