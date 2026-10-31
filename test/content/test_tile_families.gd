extends "res://test/helpers/die_fighter_test.gd"
## The tile families and their unlock order (TileUnlocks): every family is in
## the order, and every offered tile that leans on a mechanic a new player
## hasn't met waits in a family instead of being on offer from the start.

const FAMILY_DIR: String = "res://Source/Content/Tiles/TileFamilies/"
const TILE_DIR: String = "res://Source/Content/Tiles/TileResources/"
const CSV_PATH: String = "res://Localization/translations.csv"

## Keyword tokens that mark a tile as more than Basic. Evasion and Phased
## (you) read plainly off the tile, so they're Basic.
const _ADVANCED_TOKENS: Array[String] = [
	"(feed_", "(fed)", "(burn)", "(jam", "(scrambl", "(expos", "(weak",
	"(hologram", "(Hologram", "(countdown", "(echo)",
]
## A note that a tile is skipped by Echo isn't the tile using Echo.
const _NOT_A_USE: String = "Ignores (echo)"


func test_every_family_is_in_the_unlock_order_once() -> void:
	var ordered: Array[String] = []
	for family: TileFamilyResource in TileUnlocks.families():
		assert_false(family.id() in ordered, "%s is in the order twice" % family.id())
		ordered.append(family.id())
	for path: String in Utils.list_resource_paths(FAMILY_DIR):
		var res: Resource = load(path)
		if res is TileFamilyResource:
			assert_has(ordered, res.id(), "%s isn't in tile_unlock_order.tres, so it never unlocks" % path)


## A card shows every tile its family lists, so a tile in two families would
## be on the first card but not on offer until the second.
func test_each_tile_is_in_one_family() -> void:
	var seen: Dictionary[String, String] = {}
	for family: TileFamilyResource in TileUnlocks.families():
		for tile: TileResource in family.tiles:
			if tile == null:
				continue
			assert_false(seen.has(tile.resource_path), "%s is in both %s and %s" % [
				tile.resource_path, seen.get(tile.resource_path, ""), family.id()])
			seen[tile.resource_path] = family.id()


func test_family_tiles_are_offered_tiles() -> void:
	for family: TileFamilyResource in TileUnlocks.families():
		assert_false(family.tiles.is_empty(), "%s has no tiles" % family.id())
		for tile: TileResource in family.tiles:
			assert_not_null(tile, "%s lists an empty slot" % family.id())
			if tile:
				assert_true(tile.offered_as_reward,
					"%s lists %s, which is never offered" % [family.id(), tile.resource_path])


func test_advanced_tiles_wait_in_a_family() -> void:
	var basic: int = 0
	for path: String in Utils.list_resource_paths(TILE_DIR):
		var tile: TileResource = load(path)
		if tile == null or not tile.offered_as_reward:
			continue
		var text: String = (tile.activation_description + " " + tile.description).replace(_NOT_A_USE, "")
		var advanced: bool = false
		for token: String in _ADVANCED_TOKENS:
			advanced = advanced or token in text
		if TileUnlocks.families_of(tile).is_empty():
			basic += 1
			assert_false(advanced, "%s uses an advanced keyword but is in no family, so a new player is offered it" % path)
	gut.p("%d Basic tiles on offer to a new player" % basic)
	assert_gt(basic, 40, "the Basic pool should be big enough to build a run from")


func test_family_text_is_translated() -> void:
	var csv: String = FileAccess.get_file_as_string(CSV_PATH)
	for family: TileFamilyResource in TileUnlocks.families():
		for key: String in [family.family_name, family.description]:
			assert_true(csv.contains("\n" + key + ","), "%s has no row in translations.csv" % key)
