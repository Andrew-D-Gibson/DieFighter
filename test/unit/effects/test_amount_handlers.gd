extends "res://test/helpers/die_fighter_test.gd"
## AMOUNT_MODIFIER handlers that read game state rather than the EffectData.
## (SET / ADD / MULTIPLY / SET_TO_DIE_VALUE are covered via test_effect_chain.)

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const Sub := EffectEnums.AmountModifierSubtype

var engine: RecordingEngine
var context: EffectContext


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	context = EffectContext.new()


func _apply(subtype: Sub) -> int:
	var data := Effects.data(EffectEnums.Category.AMOUNT_MODIFIER, subtype)
	await EffectRegistry.get_handler(data.category, data.subtype).apply(data, context, engine)
	return context.running_amount


func test_set_to_enemy_intent() -> void:
	context.enemy_intent_amount = 7
	assert_eq(await _apply(Sub.SET_TO_ENEMY_INTENT), 7)


func test_set_to_engine_charge() -> void:
	Globals.player = make_player(5, 9)
	assert_eq(await _apply(Sub.SET_TO_ENGINE_CHARGE), 9)


func test_set_to_missing_charge_bottoms_out_at_zero() -> void:
	var player := make_player(5)
	Globals.player = player
	player.engine_charge = player.max_engine_charge - 4
	assert_eq(await _apply(Sub.SET_TO_MISSING_CHARGE), 4)
	player.engine_charge = player.max_engine_charge + 3
	assert_eq(await _apply(Sub.SET_TO_MISSING_CHARGE), 0)


func test_set_to_overcharge_is_zero_below_max() -> void:
	var player := make_player(5)
	Globals.player = player
	player.engine_charge = player.max_engine_charge - 1
	assert_eq(await _apply(Sub.SET_TO_OVERCHARGE), 0)
	player.engine_charge = player.max_engine_charge + 3
	assert_eq(await _apply(Sub.SET_TO_OVERCHARGE), 3)


func test_charge_readers_leave_the_amount_alone_without_a_player() -> void:
	Globals.player = null
	context.running_amount = 5
	assert_eq(await _apply(Sub.SET_TO_MISSING_CHARGE), 5)
	assert_eq(await _apply(Sub.SET_TO_OVERCHARGE), 5)


func test_add_repetitions_adds_the_running_amount() -> void:
	context.repetitions = 1
	context.running_amount = 2
	var data := Effects.add_repetitions()
	await EffectRegistry.get_handler(data.category, data.subtype).apply(data, context, engine)
	assert_eq(context.repetitions, 3)


func test_set_to_feed_depth() -> void:
	context.running_amount = 9
	context.feed_depth = 3
	assert_eq(await _apply(Sub.SET_TO_FEED_DEPTH), 3)
	context.feed_depth = 0
	assert_eq(await _apply(Sub.SET_TO_FEED_DEPTH), 0)


func test_set_to_activations_this_turn() -> void:
	var grid: TileGrid = autofree(TileGrid.new())
	grid.activations_this_turn = 4
	Globals.tile_grid = grid
	assert_eq(await _apply(Sub.SET_TO_ACTIVATIONS_THIS_TURN), 4)


# ── Fleet readers ─────────────────────────────────────────────────────────────

const _DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")


## A ship-shaped stand-in holding `count` real dice, for the readers that
## look at a target's dice_manager. Kept out of the tree, like every Dice here.
func _ship_holding(count: int) -> Node:
	var ship: Player = autofree(Player.new())
	ship.dice_manager = autofree(DiceQueue.new())
	for i: int in count:
		ship.dice_manager.queue.append(autofree(_DICE_SCENE.instantiate()))
	return ship


func test_set_to_dice_owned_reads_the_fleet() -> void:
	Globals.player = make_player(4)
	assert_eq(await _apply(Sub.SET_TO_DICE_OWNED), 4)


func test_set_to_target_dice_held_counts_the_first_targets_dice() -> void:
	context.targets = [_ship_holding(3), _ship_holding(1)]
	assert_eq(await _apply(Sub.SET_TO_TARGET_DICE_HELD), 3)


func test_set_to_target_dice_held_is_zero_without_a_target() -> void:
	context.running_amount = 9
	assert_eq(await _apply(Sub.SET_TO_TARGET_DICE_HELD), 0)
