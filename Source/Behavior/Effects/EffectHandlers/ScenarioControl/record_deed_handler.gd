class_name RecordDeedHandler
extends EffectHandler
## string_param names the deed (FateLedger.DEED_*).


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event: RecordDeedEvent = RecordDeedEvent.new()
	_stamp(event, context)
	event.deed = data.string_param
	engine.inject_event(event)
