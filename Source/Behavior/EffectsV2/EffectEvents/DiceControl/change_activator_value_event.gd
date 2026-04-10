class_name ChangeActivatorValueEvent
extends EffectEvent

## The value to set the activator die to.
## amount (from EffectEvent base) holds this value.

func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die):
		return
	await activator_die.reroll_with_tween(amount)
