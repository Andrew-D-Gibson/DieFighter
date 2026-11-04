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


func test_upgraded_tiles_never_appear_as_separate_entries() -> void:
	CollectionManager.record_tile("damage_plus")
	CollectionManager.record_tile("reroll_plus")
	var ids: Array[String] = CodexCatalog.tile_ids()
	for id: String in ids:
		var tile: TileResource = CodexCatalog.tile_resource(id)
		assert_false(tile.is_upgrade, "%s is an upgrade and belongs behind its base entry's toggle" % id)
	assert_true(CodexCatalog.is_tile_found("damage"), "finding the upgrade marks the base entry found")


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
	# Read from the drone's own options, so retuning or renaming its actions
	# never fails this; only the merging is checked.
	var order: Array[EnemyActionResource] = []
	var lows: Dictionary[String, int] = {}
	var highs: Dictionary[String, int] = {}
	var options_seen: int = 0
	for pool: EnemyTurnActionList in CANNON_DRONE.action_options:
		for option: EnemyActionOptionResource in pool.actions_possible:
			var action: EnemyActionResource = option.base_action
			if not action or action.name.is_empty():
				continue
			options_seen += 1
			if not lows.has(action.name):
				order.append(action)
				lows[action.name] = option.min_amount
				highs[action.name] = option.max_amount
			else:
				lows[action.name] = mini(lows[action.name], option.min_amount)
				highs[action.name] = maxi(highs[action.name], option.max_amount)
	assert_gt(options_seen, order.size(), "the drone still rolls one action from several options")

	var lines: Array[String] = CodexCatalog.enemy_action_lines(CANNON_DRONE)
	assert_eq(lines.size(), order.size(), "one line per action")
	for i: int in mini(lines.size(), order.size()):
		var action: EnemyActionResource = order[i]
		assert_string_contains(lines[i], action.display_name())
		assert_string_contains(lines[i], CodexCatalog.amount_range_text(lows[action.name], highs[action.name]))


func test_amount_ranges() -> void:
	assert_eq(CodexCatalog.amount_range_text(0, 0), "")
	assert_eq(CodexCatalog.amount_range_text(3, 3), "3")
	assert_eq(CodexCatalog.amount_range_text(2, 5), "2-5")
	assert_eq(CodexCatalog.amount_range_text(0, 4), "4")


func test_names_sort_without_their_colour_tags() -> void:
	assert_eq(CodexCatalog.plain_name("[color=red]Chain Cannon[/color]"), "chain cannon")
