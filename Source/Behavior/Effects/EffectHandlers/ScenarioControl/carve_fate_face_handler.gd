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
	engine.inject_event(event)
