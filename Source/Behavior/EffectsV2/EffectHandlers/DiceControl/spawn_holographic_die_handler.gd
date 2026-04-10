class_name SpawnHolographicDieHandler
extends EffectHandler

## data.amount: number of holographic dice to spawn.
## Uses the activator die's current value as the face value for spawned dice.

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event := SpawnHolographicDieEvent.new()
	event.actor         = context.actor
	event.activator_die = context.activator_die
	event.amount        = data.amount
	event.die_value     = context.activator_die.value if is_instance_valid(context.activator_die) else 1
	engine.queue_event(event)
