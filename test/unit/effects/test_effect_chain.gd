extends "res://test/helpers/die_fighter_test.gd"
## EffectChain.play(): running amounts, repetitions, and the events it hands
## the engine. A RecordingEngine captures those events instead of resolving
## them, so no scene is needed.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")

var engine: RecordingEngine
var context: EffectContext
var target: Node2D


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	target = autofree(Node2D.new())
	context = EffectContext.new()
	context.actor = autofree(Node2D.new())
	context.effect_source = autofree(Node2D.new())
	context.targets = [target]


func _damage_amounts() -> Array:
	return engine.injected_of(DamageEvent).map(func(e: EffectEvent) -> int: return e.amount)


func test_amount_modifiers_run_in_order_into_the_damage() -> void:
	var chain := Effects.chain([
		Effects.set_amount(3), Effects.add_amount(2), Effects.multiply(2.0), Effects.damage(),
	])
	await chain.play(context, engine)
	assert_eq(_damage_amounts(), [10])


func test_multiply_truncates_toward_zero() -> void:
	await Effects.chain([Effects.set_amount(5), Effects.multiply(1.5), Effects.damage()]).play(context, engine)
	assert_eq(_damage_amounts(), [7])


func test_events_are_stamped_with_the_chain_context() -> void:
	context.activator_die = autofree(FakeDie.new(4))
	await Effects.chain([Effects.die_value(), Effects.damage()]).play(context, engine)

	var hit: DamageEvent = engine.injected_of(DamageEvent)[0]
	assert_eq(hit.amount, 4)
	assert_eq(hit.die_value, 4)
	assert_same(hit.actor, context.actor)
	assert_same(hit.effect_source, context.effect_source)
	assert_eq(hit.targets, [target] as Array[Node])


func test_event_targets_are_a_snapshot_not_the_live_context() -> void:
	await Effects.chain([Effects.set_amount(1), Effects.damage()]).play(context, engine)
	context.targets.clear()
	assert_eq(engine.injected_of(DamageEvent)[0].targets.size(), 1)


func test_damage_with_no_targets_produces_nothing() -> void:
	context.targets = []
	await Effects.chain([Effects.set_amount(3), Effects.damage()]).play(context, engine)
	assert_eq(engine.injected.size(), 0)


func test_base_repetitions_replay_the_chain_with_a_fresh_amount() -> void:
	await Effects.chain([Effects.add_amount(2), Effects.damage()], 3).play(context, engine)
	assert_eq(_damage_amounts(), [2, 2, 2], "running_amount resets each repetition")


func test_caller_repetitions_multiply_with_base_repetitions() -> void:
	context.repetitions = 2
	await Effects.chain([Effects.set_amount(1), Effects.damage()], 3).play(context, engine)
	assert_eq(_damage_amounts().size(), 6)


func test_repetition_conditions_add_loops_when_they_hold() -> void:
	var chain := Effects.chain([Effects.set_amount(1), Effects.damage()])
	chain.repetition_conditions = [Effects.conditional(
		EffectEnums.ConditionalSubtype.IF_ACTIVATOR_ODD,
		[Effects.set_amount(2), Effects.add_repetitions()],
	)]

	context.activator_die = autofree(FakeDie.new(3))
	await chain.play(context, engine)
	assert_eq(_damage_amounts().size(), 3, "odd die: 1 + 2 extra")


func test_repetition_conditions_do_nothing_when_they_fail() -> void:
	var chain := Effects.chain([Effects.set_amount(1), Effects.damage()])
	chain.repetition_conditions = [Effects.conditional(
		EffectEnums.ConditionalSubtype.IF_ACTIVATOR_ODD,
		[Effects.set_amount(2), Effects.add_repetitions()],
	)]

	context.activator_die = autofree(FakeDie.new(4))
	await chain.play(context, engine)
	assert_eq(_damage_amounts().size(), 1)


func test_repetition_inside_effects_is_rejected_not_obeyed() -> void:
	var chain := Effects.chain([
		Effects.set_amount(5), Effects.add_repetitions(), Effects.damage(),
	])
	await chain.play(context, engine)
	assert_eq(_damage_amounts().size(), 1, "the loop can't extend itself")
	assert_push_error("REPETITION effects are not valid")


func test_repetitions_after_the_first_snap_the_die_back_first() -> void:
	var die: Node2D = autofree(FakeDie.new(2))
	die.global_position = Vector2(12, 34)
	context.activator_die = die

	await Effects.chain([Effects.set_amount(1), Effects.damage()], 3).play(context, engine)

	var snaps: Array[EffectEvent] = engine.injected_of(SnapDieToPositionEvent)
	assert_eq(snaps.size(), 2, "one before each repetition after the first")
	assert_eq((snaps[0] as SnapDieToPositionEvent).target_position, Vector2(12, 34))
	assert_true(engine.injected[0] is DamageEvent, "no snap before the first repetition")
