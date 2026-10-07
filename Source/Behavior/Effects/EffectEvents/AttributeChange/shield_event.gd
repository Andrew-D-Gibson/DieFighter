class_name ShieldEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	if targets.is_empty():
		return

	for target: Node in targets:
		if not is_instance_valid(target):
			continue
		target.health.change_shields(amount)
		# The player's gain shows on their health bar; a ship's floats off it.
		if target is Enemy and amount > 0:
			Juice.callout(target, "+%d" % amount, Globals.blue)
