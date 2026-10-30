class_name AddEvasionEvent
extends EffectEvent
## Raises the player's evasion by [member amount] percentage points until the
## enemy turn ends (EvasionModifier.add_bonus()). The total still stops at the
## cap, so the callout says what the boost actually added.


## Percentage points, not an output: an Amplifier's +1 would be +1%.
func is_amplifiable() -> bool:
	return false


func resolve(engine: ScenarioEngine) -> void:
	var evasion: EvasionModifier = EvasionModifier.find(engine)
	if evasion == null or amount <= 0:
		return
	var before: int = evasion.chance_percent()
	evasion.add_bonus(amount)
	var gained: int = evasion.chance_percent() - before
	var source: Node2D = effect_source as Node2D
	if gained > 0 and is_instance_valid(source) and source.is_inside_tree():
		Juice.callout(source, "+%d%%" % gained, Globals.purple)
