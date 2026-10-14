class_name LaunchShipHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.actor) or data.ship_resource == null:
		return

	var event := LaunchShipEvent.new()
	_stamp(event, context)
	event.ship_resource = data.ship_resource
	engine.inject_event(event)
