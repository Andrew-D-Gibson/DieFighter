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
			Juice.callout(target, "+%d" % amount, Globals.blue, false, uncapped_gain_text(), cap_color())


## A multiplier gain sets this to the target's original shields times its
## factor. One Amplify then doubles the factor, independently of flat gains.
var amplification_unit: int = 1


func amplify(bonus: int) -> void:
	amount += bonus * amplification_unit
