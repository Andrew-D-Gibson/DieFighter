class_name EnemyActionWeightRule
extends Resource
## Scales an action option's weight while a condition holds: Repair Beam ×3
## while an ally is hurt, a raid ×2 while it's the pirates' only target.
## Changes how often a slot rolls the action, never what a rolled slot does.

@export var condition: EnemyActionCondition

## Multiplies the option's weight while [member condition] is met. 0 drops the
## option from the weighted fill (a force_include still appears).
@export_range(0.0, 10.0, 0.25, "or_greater") var multiplier: float = 2.0


func factor(situation: EnemyActionSituation) -> float:
	if condition == null or not condition.is_met(situation):
		return 1.0
	return multiplier
