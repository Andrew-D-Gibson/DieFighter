class_name WaitEvent
extends EffectEvent

## amount (from EffectEvent base) is the wait duration in milliseconds.

func resolve(engine: ScenarioEngine) -> void:
	if amount <= 0:
		return
	await engine.get_tree().create_timer(amount / 1000.0).timeout
