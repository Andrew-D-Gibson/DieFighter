class_name SpawnExplosionParticlesHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event := SpawnExplosionParticlesEvent.new()
	event.actor          = context.actor
	event.effect_source  = context.effect_source
	event.activator_die  = context.activator_die
	event.targets        = context.targets.duplicate()
	event.color          = data.color
	event.amount         = context.running_amount
	engine.inject_event(event)
