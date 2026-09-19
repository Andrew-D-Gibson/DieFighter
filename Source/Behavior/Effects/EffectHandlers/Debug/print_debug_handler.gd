class_name PrintDebugHandler
extends EffectHandler

func apply(data: EffectData, _context: EffectContext, engine: ScenarioEngine) -> void:
	var event: PrintDebugEvent = PrintDebugEvent.new()
	event.metadata["message"] = "PrintDebugEvent: " + data.string_param
	
	engine.inject_event(event)
