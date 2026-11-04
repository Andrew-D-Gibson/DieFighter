class_name GrappleHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.activator_die) or not is_instance_valid(context.actor):
		return

	var event := GrappleEvent.new()
	_stamp(event, context)
	event.color = data.color
	event.clamp_sfx = data.sound_resource
	engine.inject_event(event)
