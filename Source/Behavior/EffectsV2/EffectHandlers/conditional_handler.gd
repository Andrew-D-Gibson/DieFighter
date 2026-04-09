## ConditionalHandler
## Evaluates a condition and runs the appropriate branch of a
## ConditionalEffectData.
##
## Adding a new condition:
##   1. Add a value to EffectEnums.ConditionalSubtype.
##   2. Add a match arm in _evaluate_condition().
##   3. Register it in EffectRegistry (it maps to this same handler).

class_name ConditionalHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not data is ConditionalEffectData:
		push_error("ConditionalHandler received non-ConditionalEffectData. " +
				   "Make sure your CONDITIONAL EffectData resources are ConditionalEffectData.")
		return

	var cdata := data as ConditionalEffectData
	var condition_met: bool = _evaluate_condition(cdata, context)
	var branch: Array[EffectData] = cdata.if_true_effects if condition_met else cdata.if_false_effects

	# Execute the chosen branch exactly like EffectChainV2.play() does,
	# but without looping (conditionals don't have their own repetitions).
	for effect_data: EffectData in branch:
		var handler: EffectHandler = EffectRegistry.get_handler(effect_data.category, effect_data.subtype)
		if handler == null:
			continue
		await handler.apply(effect_data, context, engine)


func _evaluate_condition(data: ConditionalEffectData, context: EffectContext) -> bool:
	match data.subtype:
		EffectEnums.ConditionalSubtype.IF_ACTIVATOR_ODD:
			return _is_activator_odd(context)

		EffectEnums.ConditionalSubtype.IF_ENEMY_TARGETED:
			return _is_enemy_targeted(context)

		EffectEnums.ConditionalSubtype.IF_ENGINE_CHARGED:
			return _is_engine_charged()

		EffectEnums.ConditionalSubtype.IF_DIE_VALUE_IN_RANGE:
			return _is_die_in_range(data, context)

		_:
			push_error("ConditionalHandler: unhandled subtype %d" % data.subtype)
			return false


func _is_activator_odd(context: EffectContext) -> bool:
	if context.activator_die == null:
		return false
	return context.activator_die.value % 2 != 0


func _is_enemy_targeted(context: EffectContext) -> bool:
	return not context.targets.is_empty() and context.targets[0] is Enemy


func _is_engine_charged() -> bool:
	if Globals.player == null:
		return false
	# Adjust this call to match your actual EngineCharger API.
	return Globals.player.engine_charger.is_charged()


func _is_die_in_range(data: ConditionalEffectData, context: EffectContext) -> bool:
	if context.activator_die == null:
		return false
	var v: int = context.activator_die.value
	return v >= data.range_min and v <= data.range_max
