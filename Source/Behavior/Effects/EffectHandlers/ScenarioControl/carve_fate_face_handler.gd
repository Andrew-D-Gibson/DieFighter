class_name CarveFateFaceHandler
extends EffectHandler
## string_param names the face (FateDie.face_id()).


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var face: int = FateDie.face_from_id(data.string_param)
	if face <= 0:
		push_error("CarveFateFaceHandler: '%s' is not a face of Fate's Die" % data.string_param)
		return
	var event: CarveFateFaceEvent = CarveFateFaceEvent.new()
	_stamp(event, context)
	event.face = face as FateDie.Face
	var ship: Enemy = context.effect_source as Enemy
	if is_instance_valid(ship) and ship.scenario_state:
		event.source = ship.scenario_state.resource_path
	engine.inject_event(event)
