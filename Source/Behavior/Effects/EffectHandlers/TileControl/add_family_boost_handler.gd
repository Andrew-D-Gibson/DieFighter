class_name AddFamilyBoostHandler
extends EffectHandler
## Raises (or, with a negative running amount, lowers) the source tile's
## fight-long damage boost for one colour family of tiles (War Footing).
## string_param names the family, range_max caps the boost.


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var family: ColorSymbolBadge.Family = FamilyBoostModifier.family_named(data.string_param)
	if family == ColorSymbolBadge.Family.NONE:
		push_error("AddFamilyBoostHandler: unknown tile family '%s'" % data.string_param)
		return
	# Losing a boost there isn't queues nothing, so a hull hit with no War
	# Footing built doesn't light the tile up for doing nothing.
	if context.running_amount < 0 \
			and FamilyBoostModifier.find(engine, context.effect_source, family) == null:
		return

	var event: AddFamilyBoostEvent = AddFamilyBoostEvent.new()
	_stamp(event, context)
	event.family = family
	event.cap = data.range_max
	event.amount = context.running_amount
	engine.inject_event(event)
