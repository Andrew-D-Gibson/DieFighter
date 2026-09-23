class_name SpawnHolographicDieHandler
extends EffectHandler

## context.running_amount: the FACE VALUE of the hologram to spawn, not a count
## — SpawnHolographicDieEvent spawns exactly one die per invocation and passes
## `amount` through as its value. Author several by giving the chain
## base_repetitions, the way Holo-Duplicator does for its two.
##
## die_value is set below for modifiers that read it off the event; the spawn
## itself does not use it.

func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event := SpawnHolographicDieEvent.new()
	_stamp(event, context)
	event.amount        = context.running_amount
	event.die_value     = context.activator_die.value if is_instance_valid(context.activator_die) else 1
	engine.inject_event(event)
