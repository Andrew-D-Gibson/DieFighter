class_name OpenShopHandler
extends EffectHandler


func apply(_data: EffectData, _context: EffectContext, engine: ScenarioEngine) -> void:
	var event: OpenShopEvent = OpenShopEvent.new()
	engine.inject_event(event)
