class_name ChangeActivatorValueEvent
extends EffectEvent

## The value to set the activator die to.
## amount (from EffectEvent base) holds this value.

## amount is the face value to roll to — boosting it past 6 is not a die.
func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die):
		return
	await activator_die.reroll_with_tween(amount)
