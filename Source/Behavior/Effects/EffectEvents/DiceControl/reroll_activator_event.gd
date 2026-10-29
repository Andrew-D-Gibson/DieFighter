class_name RerollActivatorEvent
extends EffectEvent


## See EffectEvent.changes_die_values().
func changes_die_values() -> bool:
	return true


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die):
		return
	await activator_die.reroll_with_tween()
