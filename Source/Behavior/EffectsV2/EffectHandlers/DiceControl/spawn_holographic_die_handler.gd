class_name SpawnHolographicDieHandler
extends EffectHandler

## context.running_amount: number of holographic dice to spawn.
## Uses the activator die's current value as the face value for spawned dice.

func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event := SpawnHolographicDieEvent.new()
	event.actor         = context.actor
	event.activator_die = context.activator_die
	event.amount        = context.running_amount
	event.die_value     = context.activator_die.value if is_instance_valid(context.activator_die) else 1
	engine.inject_event(event)
