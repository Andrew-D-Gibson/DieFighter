class_name AddFamilyBoostEvent
extends EffectEvent
## Moves the source tile's FamilyBoostModifier for [member family] by
## [member amount], held between 0 and [member cap]. Puts one in play the
## first time, and takes it out once it falls to 0.

var family: ColorSymbolBadge.Family = ColorSymbolBadge.Family.NONE
var cap: int = 0


## The amount is a step on a counter, not an output: an Amplifier beside War
## Footing doesn't make it build faster.
func is_amplifiable() -> bool:
	return false


func resolve(engine: ScenarioEngine) -> void:
	var source: Node2D = effect_source as Node2D
	if family == ColorSymbolBadge.Family.NONE or not is_instance_valid(source) or amount == 0:
		return
	var boost: FamilyBoostModifier = FamilyBoostModifier.find(engine, source, family)
	var before: int = boost.bonus if boost else 0
	var after: int = clampi(before + amount, 0, maxi(cap, 0))
	if after == before:
		return
	if boost == null:
		boost = FamilyBoostModifier.new(source, family)
		boost.bonus = after
		engine.add_modifier(boost)
	elif after == 0:
		engine.remove_modifier(boost)
	else:
		boost.bonus = after
	if source.is_inside_tree():
		Juice.callout(source, "%+d" % (after - before), Globals.yellow if after > before else Globals.red)
