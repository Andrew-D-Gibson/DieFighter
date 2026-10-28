## ConditionalHandler
## Evaluates a condition and runs the appropriate branch of a
## ConditionalEffectData.
##
## Adding a new condition:
##   1. Add a value to EffectEnums.ConditionalSubtype.
##   2. Add a match arm in _evaluate_condition().
##   3. Add a row for it in EffectCatalog, pointing at this same handler.

class_name ConditionalHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not data is ConditionalEffectData:
		push_error("ConditionalHandler received non-ConditionalEffectData. " +
				   "Make sure your CONDITIONAL EffectData resources are ConditionalEffectData.")
		return

	var cdata := data as ConditionalEffectData
	var condition_met: bool = _evaluate_condition(cdata, context, engine)
	var branch: Array[EffectData] = cdata.if_true_effects if condition_met else cdata.if_false_effects

	# Execute the chosen branch exactly like EffectChain.play() does,
	# but without looping (conditionals don't have their own repetitions).
	for effect_data: EffectData in branch:
		var handler: EffectHandler = EffectRegistry.get_handler(effect_data.category, effect_data.subtype)
		if handler == null:
			continue
		await handler.apply(effect_data, context, engine)


func _evaluate_condition(data: ConditionalEffectData, context: EffectContext, engine: ScenarioEngine) -> bool:
	match data.subtype:
		EffectEnums.ConditionalSubtype.IF_ACTIVATOR_ODD:
			return _is_activator_odd(context)

		EffectEnums.ConditionalSubtype.IF_ENEMY_TARGETED:
			return _is_enemy_targeted(context)

		EffectEnums.ConditionalSubtype.IF_ENGINE_CHARGED:
			return _is_engine_charged()

		EffectEnums.ConditionalSubtype.IF_OVERCHARGED:
			return _is_overcharged()

		EffectEnums.ConditionalSubtype.IF_DIE_VALUE_IN_RANGE:
			return _is_die_in_range(data, context)

		EffectEnums.ConditionalSubtype.IF_TARGET_HOLDS_MATCHING_DIE:
			return _target_holds_matching_die(context)

		EffectEnums.ConditionalSubtype.IF_FED:
			return context.feed_depth > 0

		EffectEnums.ConditionalSubtype.IF_SOURCE_HOLDS_DIE:
			return context.effect_source is Tile \
				and (context.effect_source as Tile).get_held_die(context.activator_die) != null

		EffectEnums.ConditionalSubtype.IF_DICE_OWNED_IN_RANGE:
			if Globals.player == null:
				return false
			var owned: int = Globals.player.dice_owned()
			return owned >= data.range_min and owned <= data.range_max

		EffectEnums.ConditionalSubtype.IF_TARGET_HAS_STATUS:
			return not context.targets.is_empty() and is_instance_valid(context.targets[0]) \
				and engine.find_status(context.targets[0], StringName(data.string_param)) != null

		EffectEnums.ConditionalSubtype.IF_IN_COMBAT:
			return Globals.state_manager != null \
				and Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT

		EffectEnums.ConditionalSubtype.IF_CHARGE_AT_LEAST:
			return Globals.player != null and Globals.player.engine_charge >= data.amount

		EffectEnums.ConditionalSubtype.IF_SOURCE_IN_ROW:
			return _is_source_in_row(data, context)

		_:
			push_error("ConditionalHandler: unhandled subtype %d" % data.subtype)
			return false


func _is_activator_odd(context: EffectContext) -> bool:
	if context.activator_die == null:
		return false
	return context.activator_die.value % 2 != 0


func _is_enemy_targeted(context: EffectContext) -> bool:
	return not context.targets.is_empty() and context.targets[0] is Enemy


func _is_overcharged() -> bool:
	if Globals.player == null:
		return false
	return Globals.player.is_overcharged()


func _is_source_in_row(data: ConditionalEffectData, context: EffectContext) -> bool:
	var tile: Tile = context.effect_source as Tile
	var grid: TileGrid = Globals.tile_grid
	if tile == null or not is_instance_valid(grid):
		return false
	# (-1, -1) when the tile isn't on the grid, which no row range holds.
	var row: int = grid.find_tile_pos(tile).y
	return row >= 0 and row >= data.range_min and row <= data.range_max


func _is_engine_charged() -> bool:
	if Globals.player == null:
		return false
	return Globals.player.is_engine_charged()


func _is_die_in_range(data: ConditionalEffectData, context: EffectContext) -> bool:
	if context.activator_die == null:
		return false
	var v: int = context.activator_die.value
	return v >= data.range_min and v <= data.range_max


## True when the first target is already holding a die showing the same value as
## the one being spent. The most on-theme condition the game can ask: it makes
## the player track which numbers they've already handed away and stack
## punishment onto them.
func _target_holds_matching_die(context: EffectContext) -> bool:
	if context.activator_die == null:
		return false
	if context.targets.is_empty() or not is_instance_valid(context.targets[0]):
		return false

	var queue: DiceQueue = context.targets[0].get("dice_manager") as DiceQueue
	if queue == null:
		return false

	return queue.has_value(context.activator_die.value)
