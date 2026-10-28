extends "res://test/helpers/die_fighter_test.gd"
## CodexCatalog: which tiles and enemies the codex lists, in what order, and
## how it describes an enemy's actions.

const CANNON_DRONE: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/cannon_drone.tres")


func before_each() -> void:
	super()
	CollectionManager.clear()


func after_each() -> void:
	CollectionManager.clear()
	super()


func test_held_out_tiles_are_listed_only_if_a_ship_starts_with_them_or_they_were_found() -> void:
	var ids: Array[String] = CodexCatalog.tile_ids()
	assert_has(ids, "amplifier", "offered as a reward")
	assert_has(ids, "gearbox", "held out, but a ship starts with it")
	assert_does_not_have(ids, "beam_splitter", "held out and never owned")

	CollectionManager.record_tile("beam_splitter")
	assert_has(CodexCatalog.tile_ids(), "beam_splitter", "held out, but the player owned it")


func test_tiles_are_grouped_by_colour() -> void:
	var last_rank: int = -1
	for id: String in CodexCatalog.tile_ids():
		var rank: int = CodexCatalog._tile_colour_rank(CodexCatalog.tile_resource(id))
		assert_true(rank >= last_rank, "%s is out of its colour group" % id)
		last_rank = rank


func test_ships_that_arent_foes_stay_out_of_the_enemy_list() -> void:
	var ids: Array[String] = CodexCatalog.enemy_ids()
	assert_has(ids, "attacker")
	for id: String in ["shop", "repair_dock", "civilian_transport"]:
		assert_does_not_have(ids, id)


func test_an_action_rolled_by_several_options_is_listed_once_with_its_whole_range() -> void:
	var lines: Array[String] = CodexCatalog.enemy_action_lines(CANNON_DRONE)
	var cannon_lines: Array[String] = []
	for line: String in lines:
		if line.contains("Dice Cannon"):
			cannon_lines.append(line)
	assert_eq(cannon_lines.size(), 1)
	assert_string_contains(cannon_lines[0], "1-12 damage")


func test_amount_ranges() -> void:
	assert_eq(CodexCatalog.amount_range_text(0, 0), "")
	assert_eq(CodexCatalog.amount_range_text(3, 3), "3")
	assert_eq(CodexCatalog.amount_range_text(2, 5), "2-5")
	assert_eq(CodexCatalog.amount_range_text(0, 4), "4")


func test_names_sort_without_their_colour_tags() -> void:
	assert_eq(CodexCatalog.plain_name("[color=red]Chain Cannon[/color]"), "chain cannon")
