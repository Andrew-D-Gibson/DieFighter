extends "res://test/helpers/die_fighter_test.gd"
## RewardManager.filter_by_minimum_rarity: the floor elites and bosses raise
## so their salvage is rarer than an ordinary fight's.


func _tile(rarity: TileResource.Rarity) -> TileResource:
	var tile := TileResource.new()
	tile.rarity = rarity
	return tile


func test_a_common_floor_keeps_everything() -> void:
	var pool: Array[TileResource] = [
		_tile(TileResource.Rarity.COMMON),
		_tile(TileResource.Rarity.UNCOMMON),
		_tile(TileResource.Rarity.RARE),
	]
	assert_eq(RewardManager.filter_by_minimum_rarity(pool, TileResource.Rarity.COMMON), pool)


func test_the_floor_drops_tiles_below_it() -> void:
	var common := _tile(TileResource.Rarity.COMMON)
	var uncommon := _tile(TileResource.Rarity.UNCOMMON)
	var rare := _tile(TileResource.Rarity.RARE)
	var pool: Array[TileResource] = [common, uncommon, rare]

	var filtered: Array[TileResource] = RewardManager.filter_by_minimum_rarity(
		pool, TileResource.Rarity.UNCOMMON
	)
	assert_eq(filtered.size(), 2)
	assert_does_not_have(filtered, common)
	assert_has(filtered, uncommon)
	assert_has(filtered, rare)


func test_a_floor_nothing_meets_falls_back_to_the_whole_pool() -> void:
	# A player who already owns every rare tile still gets an offer.
	var pool: Array[TileResource] = [
		_tile(TileResource.Rarity.COMMON),
		_tile(TileResource.Rarity.UNCOMMON),
	]
	assert_eq(RewardManager.filter_by_minimum_rarity(pool, TileResource.Rarity.RARE), pool)
