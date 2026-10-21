extends "res://test/helpers/die_fighter_test.gd"
## "Half of" always rounds up, wherever the game halves an amount: half of 5
## is 3. Odd inputs are the ones that catch integer division.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const DEADWEIGHT_DRIVE: TileResource = preload("res://Source/Content/Tiles/TileResources/deadweight_drive.tres")


func test_a_fractional_product_rounds_up() -> void:
	assert_eq(MultiplyAmountHandler.rounded_product(5, 0.5), 3, "half of 5")
	assert_eq(MultiplyAmountHandler.rounded_product(1, 0.5), 1, "half of 1")
	assert_eq(MultiplyAmountHandler.rounded_product(4, 0.5), 2, "an even half is exact")
	assert_eq(MultiplyAmountHandler.rounded_product(0, 0.5), 0)


func test_a_whole_product_is_not_bumped_by_float_error() -> void:
	# 10 x 0.3 is 3.0000000000000004 in floating point.
	assert_eq(MultiplyAmountHandler.rounded_product(10, 0.3), 3)
	assert_eq(MultiplyAmountHandler.rounded_product(3, 2.0), 6)


func test_a_negative_half_rounds_away_from_zero() -> void:
	# Half of a 5-point cost is still a 3-point cost.
	assert_eq(MultiplyAmountHandler.rounded_product(-5, 0.5), -3)
	assert_eq(MultiplyAmountHandler.rounded_product(5, -1.0), -5)


func test_deadweight_drive_deals_half_its_missing_charge_rounded_up() -> void:
	var player := make_player(5)
	Globals.player = player
	player.engine_charge = player.max_engine_charge - 5

	# Run just the steps that build the amount: the rest of the chain is
	# targeting, juice and the hand-off, which need the full scene.
	var context := EffectContext.new()
	var engine: RecordingEngine = autofree(RecordingEngine.new())
	for data: EffectData in DEADWEIGHT_DRIVE.effect_chain.effects:
		if data.category == EffectEnums.Category.AMOUNT_MODIFIER:
			await EffectRegistry.get_handler(data.category, data.subtype).apply(data, context, engine)
	assert_eq(context.running_amount, 3, "half of 5 missing charge")


func test_redline_hull_cost_is_half_the_overcharge_rounded_up() -> void:
	assert_eq(Player.redline_hull_cost(0), 0, "no redline, no cost")
	assert_eq(Player.redline_hull_cost(1), 1)
	assert_eq(Player.redline_hull_cost(3), 2, "half of 3")
	assert_eq(Player.redline_hull_cost(5), 3, "half of 5")
	assert_eq(Player.redline_hull_cost(10), 5)


func test_redline_headroom_is_half_the_gate_rounded_up() -> void:
	# 5 dice: a 21-charge gate, so 10.5 rounds up to 11.
	assert_eq(make_player(5).overcharge_cap, 11)
