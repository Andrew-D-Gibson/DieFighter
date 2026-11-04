extends "res://test/helpers/die_fighter_test.gd"
## Keep the vocabulary tied to actual diagonals, holes and edge behavior.

const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const TILES: String = "res://Source/Content/Tiles/TileResources/%s.tres"

var grid: TileGrid
var source: Tile
var context: EffectContext


func before_each() -> void:
	super()
	grid = autofree(TileGrid.new())
	Globals.tile_grid = grid
	var cells: Array[Vector2i] = []
	for x: int in 3:
		for y: int in 3:
			cells.append(Vector2i(x, y))
	grid.set_cells(cells)
	source = _place(Vector2i(1, 1))
	context = EffectContext.new()
	context.effect_source = source


func _place(pos: Vector2i) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	grid.tile_locations[pos] = tile
	return tile


func test_surrounding_empty_slots_include_diagonals_but_not_the_source() -> void:
	AddEmptyAdjacentCellsAmountHandler.new().apply(EffectData.new(), context, null)
	assert_eq(context.running_amount, 8)
	_place(Vector2i(0, 0))
	context.running_amount = 0
	AddEmptyAdjacentCellsAmountHandler.new().apply(EffectData.new(), context, null)
	assert_eq(context.running_amount, 7)


func test_surrounding_counts_and_targets_include_all_eight_tiles() -> void:
	for x: int in 3:
		for y: int in 3:
			if Vector2i(x, y) != Vector2i(1, 1):
				_place(Vector2i(x, y))
	AddAdjacentTilesAmountHandler.new().apply(EffectData.new(), context, null)
	assert_eq(context.running_amount, 8)
	TargetSurroundingTilesHandler.new().apply(EffectData.new(), context, null)
	assert_eq(context.targets.size(), 8)
	assert_false(context.targets.has(source))


func test_adjacent_excludes_diagonals_for_triggers_and_random_targeting() -> void:
	var diagonal: Tile = _place(Vector2i(0, 0))
	assert_false(source._is_orthogonal_neighbour(diagonal))
	assert_true(source._is_surrounding_neighbour(diagonal))
	TargetRandomAdjacentTileHandler.new().apply(EffectData.new(), context, null)
	assert_true(context.targets.is_empty())
	var beside: Tile = _place(Vector2i(1, 0))
	assert_true(source._is_orthogonal_neighbour(beside))
	TargetRandomAdjacentTileHandler.new().apply(EffectData.new(), context, null)
	assert_eq(context.targets, [beside] as Array[Node])


func test_surrounding_excludes_off_grid_and_missing_slots() -> void:
	grid.tile_locations.erase(Vector2i(1, 1))
	grid.tile_locations[Vector2i.ZERO] = source
	AddEmptyAdjacentCellsAmountHandler.new().apply(EffectData.new(), context, null)
	assert_eq(context.running_amount, 3, "only three neighbors exist at a corner")
	grid.set_cells([Vector2i.ZERO, Vector2i(1, 0)] as Array[Vector2i])
	context.running_amount = 0
	AddEmptyAdjacentCellsAmountHandler.new().apply(EffectData.new(), context, null)
	assert_eq(context.running_amount, 1, "holes are not empty slots")


func test_every_spatial_tile_uses_the_matching_keyword_and_effect() -> void:
	var amount: int = EffectEnums.Category.AMOUNT_MODIFIER
	var targeting: int = EffectEnums.Category.TARGETING
	var families: Dictionary = {
		"ram_scoop": [amount, EffectEnums.AmountModifierSubtype.ADD_EMPTY_ADJACENT_CELLS],
		"solar_sail": [amount, EffectEnums.AmountModifierSubtype.ADD_EMPTY_ADJACENT_CELLS],
		"flak_cannon": [amount, EffectEnums.AmountModifierSubtype.ADD_ADJACENT_TILES],
		"reloader": [targeting, EffectEnums.TargetingSubtype.TARGET_SURROUNDING_TILES],
	}
	for family: String in families:
		for suffix: String in ["", "_plus"]:
			var tile: TileResource = load(TILES % (family + suffix))
			assert_true(tile.description.to_lower().contains("(surrounding)"), family + suffix)
			var found: bool = false
			for effect: EffectData in tile.effect_chain.effects:
				if effect.category == families[family][0] and effect.subtype == families[family][1]:
					found = true
			assert_true(found, family + suffix)
	for family: String in ["spark_gap", "napalm_vent"]:
		for suffix: String in ["", "_plus"]:
			var tile: TileResource = load(TILES % (family + suffix))
			var term: String = "adjacent" if family == "spark_gap" else "surrounding"
			assert_true(tile.description.to_lower().contains("(" + term + ")"))
			var expected: int = TileEvent.EventType.ON_ADJACENT_TILE_ACTIVATED if family == "spark_gap" else TileEvent.EventType.ON_SURROUNDING_TILE_ACTIVATED
			var found: bool = false
			for event: TileEvent in tile.event_responses:
				found = found or event.event == expected
			assert_true(found, family + suffix)


func test_spatial_words_render_as_hoverable_keywords() -> void:
	for term: String in ["adjacent", "surrounding"]:
		for label: String in [term, term.capitalize()]:
			assert_string_contains(Keywords.render("(" + label + ")", true), "[url=" + term + "]")
		assert_false(Keywords.definition(term).is_empty())
