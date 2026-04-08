class_name PrintDebugHandler
extends EffectHandler

func apply(data: EffectData, _context: EffectContext, _engine: ScenarioEngine) -> void:
	print("PrintDebugHandler fired! EffectData string_param = ", data.string_param)
