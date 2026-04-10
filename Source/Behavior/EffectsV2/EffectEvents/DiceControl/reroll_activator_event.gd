class_name RerollActivatorEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die):
		return
	await activator_die.reroll_with_tween()
