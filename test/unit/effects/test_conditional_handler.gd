extends "res://test/helpers/die_fighter_test.gd"
## ConditionalHandler: each condition picks the right branch. Branches are
## SET amount steps, so the chosen branch shows up in context.running_amount.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const TRUE_BRANCH: int = 1
const FALSE_BRANCH: int = 2

const Cond := EffectEnums.ConditionalSubtype

var engine: RecordingEngine
var handler: ConditionalHandler
var context: EffectContext


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	handler = ConditionalHandler.new()
	context = EffectContext.new()


func _branch_taken(condition: ConditionalEffectData) -> int:
	context.running_amount = 0
	await handler.apply(condition, context, engine)
	return context.running_amount


func _cond(subtype: Cond) -> ConditionalEffectData:
	return Effects.conditional(subtype,
		[Effects.set_amount(TRUE_BRANCH)], [Effects.set_amount(FALSE_BRANCH)])


func test_if_activator_odd() -> void:
	context.activator_die = autofree(FakeDie.new(5))
	assert_eq(await _branch_taken(_cond(Cond.IF_ACTIVATOR_ODD)), TRUE_BRANCH)
	context.activator_die.value = 6
	assert_eq(await _branch_taken(_cond(Cond.IF_ACTIVATOR_ODD)), FALSE_BRANCH)


func test_conditions_on_the_die_are_false_without_one() -> void:
	context.activator_die = null
	assert_eq(await _branch_taken(_cond(Cond.IF_ACTIVATOR_ODD)), FALSE_BRANCH)
	assert_eq(await _branch_taken(_cond(Cond.IF_DIE_VALUE_IN_RANGE)), FALSE_BRANCH)


func test_if_die_value_in_range_is_inclusive() -> void:
	var cond := _cond(Cond.IF_DIE_VALUE_IN_RANGE)
	cond.range_min = 2
	cond.range_max = 4
	var die: Node2D = autofree(FakeDie.new())
	context.activator_die = die

	var taken: Array = []
	for face: int in range(1, 7):
		die.value = face
		taken.append(await _branch_taken(cond))
	assert_eq(taken, [FALSE_BRANCH, TRUE_BRANCH, TRUE_BRANCH, TRUE_BRANCH, FALSE_BRANCH, FALSE_BRANCH])


func test_if_enemy_targeted_is_false_for_no_target_or_a_non_enemy() -> void:
	context.targets = []
	assert_eq(await _branch_taken(_cond(Cond.IF_ENEMY_TARGETED)), FALSE_BRANCH)
	context.targets = [autofree(Node2D.new())]
	assert_eq(await _branch_taken(_cond(Cond.IF_ENEMY_TARGETED)), FALSE_BRANCH)


func test_if_engine_charged_reads_the_player() -> void:
	var player := make_player(5)
	Globals.player = player
	player.engine_charge = player.max_engine_charge - 1
	assert_eq(await _branch_taken(_cond(Cond.IF_ENGINE_CHARGED)), FALSE_BRANCH)
	player.engine_charge = player.max_engine_charge
	assert_eq(await _branch_taken(_cond(Cond.IF_ENGINE_CHARGED)), TRUE_BRANCH)


func test_if_overcharged_needs_charge_past_max() -> void:
	var player := make_player(5)
	Globals.player = player
	player.engine_charge = player.max_engine_charge
	assert_eq(await _branch_taken(_cond(Cond.IF_OVERCHARGED)), FALSE_BRANCH)
	player.engine_charge = player.max_engine_charge + 1
	assert_eq(await _branch_taken(_cond(Cond.IF_OVERCHARGED)), TRUE_BRANCH)


func test_player_conditions_are_false_without_a_player() -> void:
	Globals.player = null
	assert_eq(await _branch_taken(_cond(Cond.IF_ENGINE_CHARGED)), FALSE_BRANCH)
	assert_eq(await _branch_taken(_cond(Cond.IF_OVERCHARGED)), FALSE_BRANCH)


func test_if_target_holds_matching_die() -> void:
	var holder := make_player()
	var queue: DiceQueue = autofree(DiceQueue.new())
	holder.dice_manager = queue
	var held: Dice = autofree(preload("res://Source/Systems/Game/Dice/dice.tscn").instantiate())
	held.value = 3
	queue.queue.append(held)
	context.targets = [holder]
	var die: Node2D = autofree(FakeDie.new(3))
	context.activator_die = die

	assert_eq(await _branch_taken(_cond(Cond.IF_TARGET_HOLDS_MATCHING_DIE)), TRUE_BRANCH)
	die.value = 4
	assert_eq(await _branch_taken(_cond(Cond.IF_TARGET_HOLDS_MATCHING_DIE)), FALSE_BRANCH)


func test_plain_effect_data_is_rejected() -> void:
	var not_conditional := Effects.data(EffectEnums.Category.CONDITIONAL, Cond.IF_ACTIVATOR_ODD)
	await handler.apply(not_conditional, context, engine)
	assert_push_error("non-ConditionalEffectData")


func test_if_fed_reads_feed_depth() -> void:
	context.feed_depth = 0
	assert_eq(await _branch_taken(_cond(Cond.IF_FED)), FALSE_BRANCH, "placed by hand")
	context.feed_depth = 2
	assert_eq(await _branch_taken(_cond(Cond.IF_FED)), TRUE_BRANCH, "arrived through a Feed")
