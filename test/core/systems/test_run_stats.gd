extends "res://test/helpers/die_fighter_test.gd"
## RunStats: the end-of-run tallies, and that a Continue doesn't count the
## bank as earnings.

var stats: RunStats


func before_each() -> void:
	super()
	stats = RunStats.new()
	add_child_autofree(stats)


func test_sector_advances_are_one_based() -> void:
	Events.sector_advanced.emit(2)
	assert_eq(stats.sectors_reached, 3)


func test_only_money_gains_count_as_credits_earned() -> void:
	Events.set_money.emit(10)
	Events.set_money.emit(4)   # spent 6
	Events.set_money.emit(9)   # earned 5
	assert_eq(stats.credits_earned, 15)


func test_loading_a_save_rebaselines_money() -> void:
	var save := GameSaveResource.new()
	save.money = 100
	save.run_stats = {"credits_earned": 40, "encounters_cleared": 2}
	stats._load_game_save(save)
	Events.set_money.emit(100)  # Player restoring its balance
	assert_eq(stats.credits_earned, 40)
	assert_eq(stats.encounters_cleared, 2)


func test_a_save_without_stats_falls_back_to_the_sector_index() -> void:
	var save := GameSaveResource.new()
	save.sector_index = 1
	stats._load_game_save(save)
	assert_eq(stats.sectors_reached, 2)
	assert_eq(stats.ships_destroyed, 0)


func test_state_round_trips_through_a_save() -> void:
	stats.sectors_reached = 2
	stats.encounters_cleared = 5
	stats.ships_destroyed = 7
	stats.credits_earned = 30
	var save := GameSaveResource.new()
	save.run_stats = stats.get_state()

	var restored: RunStats = RunStats.new()
	add_child_autofree(restored)
	restored._load_game_save(save)
	assert_eq(restored.get_state(), stats.get_state())
