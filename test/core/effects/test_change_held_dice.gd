extends "res://test/helpers/die_fighter_test.gd"
## REROLL_TARGETS_DICE / FLIP_TARGETS_ONES_AND_SIXES (Ion Storm, Fate Rift):
## the handlers aim one ChangeHeldDiceEvent at the chain's targets, with the
## right change. The roll itself tweens real dice, so it is verified live.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")


func _apply(subtype: int, targets: Array[Node]) -> Array[EffectEvent]:
	var engine: RecordingEngine = autofree(RecordingEngine.new())
	var context := EffectContext.new()
	context.targets = targets
	var data := Effects.data(EffectEnums.Category.DICE_CONTROL, subtype)
	await EffectRegistry.get_handler(data.category, data.subtype).apply(data, context, engine)
	return engine.injected_of(ChangeHeldDiceEvent)


func test_reroll_aims_at_the_targets() -> void:
	var target: Node = autofree(Node.new())
	var events: Array[EffectEvent] = await _apply(
		EffectEnums.DiceControlSubtype.REROLL_TARGETS_DICE, [target] as Array[Node])
	assert_eq(events.size(), 1)
	assert_eq(events[0].targets, [target] as Array[Node])
	assert_eq((events[0] as ChangeHeldDiceEvent).change, ChangeHeldDiceEvent.Change.REROLL)


func test_flip_aims_at_the_targets() -> void:
	var target: Node = autofree(Node.new())
	var events: Array[EffectEvent] = await _apply(
		EffectEnums.DiceControlSubtype.FLIP_TARGETS_ONES_AND_SIXES, [target] as Array[Node])
	assert_eq(events.size(), 1)
	assert_eq((events[0] as ChangeHeldDiceEvent).change,
		ChangeHeldDiceEvent.Change.FLIP_ONES_AND_SIXES)


func test_no_targets_means_no_event() -> void:
	var events: Array[EffectEvent] = await _apply(
		EffectEnums.DiceControlSubtype.REROLL_TARGETS_DICE, [] as Array[Node])
	assert_eq(events.size(), 0)


func test_the_event_carries_the_effects_colour() -> void:
	var engine: RecordingEngine = autofree(RecordingEngine.new())
	var context := EffectContext.new()
	context.targets = [autofree(Node.new())] as Array[Node]
	var data := Effects.data(EffectEnums.Category.DICE_CONTROL,
		EffectEnums.DiceControlSubtype.REROLL_TARGETS_DICE)
	data.color = Color.CYAN
	await EffectRegistry.get_handler(data.category, data.subtype).apply(data, context, engine)
	var events: Array[EffectEvent] = engine.injected_of(ChangeHeldDiceEvent)
	assert_eq((events[0] as ChangeHeldDiceEvent).color, Color.CYAN)
