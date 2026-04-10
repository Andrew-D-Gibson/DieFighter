class_name RerollAllDiceHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event := RerollAllDiceEvent.new()
	event.actor         = context.actor
	event.activator_die = context.activator_die
	engine.queue_event(event)
