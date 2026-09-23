class_name SpawnHitParticlesHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event := SpawnHitParticlesEvent.new()
	_stamp(event, context)
	event.targets        = context.targets.duplicate()
	event.color          = data.color
	event.amount         = context.running_amount
	engine.inject_event(event)
