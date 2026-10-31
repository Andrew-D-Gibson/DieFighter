class_name OpenShopHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event: OpenShopEvent = OpenShopEvent.new()
	event.keeper = context.actor as Enemy
	engine.inject_event(event)
