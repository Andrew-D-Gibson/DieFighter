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
