extends "res://test/helpers/die_fighter_test.gd"
## HazardManager: a background's timed hazard counts down in player turns
## during a fight, fires at zero, and starts over.
##
## The manager and the background manager it reads are kept out of the tree,
## so neither hooks the real Events in _ready(). With no scenario engine
## running, firing announces itself but queues nothing.

var manager: HazardManager
var hazard: BackgroundHazardResource


func before_each() -> void:
	super()
	Globals.state_manager = null
	manager = autofree(HazardManager.new())

	hazard = BackgroundHazardResource.new()
	hazard.hazard_name = "Test Flare"
	hazard.turns_until_first = 2
	hazard.turns_between = 3

	var background: BackgroundResource = BackgroundResource.new()
	background.hazard = hazard
	var background_manager: BackgroundManager = autofree(BackgroundManager.new())
	background_manager.current_background = background
	Globals.background_manager = background_manager

	watch_signals(Events)


func test_arming_reads_the_backgrounds_hazard() -> void:
	manager._arm_for_background()
	assert_eq(manager.current_hazard, hazard)
	assert_eq(manager.turns_remaining, 2)
	assert_signal_emitted_with_parameters(Events, "hazard_armed", [hazard, 2])


func test_plain_space_arms_nothing() -> void:
	Globals.background_manager.current_background = BackgroundResource.new()
	manager._arm_for_background()
	assert_false(manager.has_hazard())
	assert_signal_emitted_with_parameters(Events, "hazard_armed", [null, 0])


func test_each_turn_counts_down() -> void:
	manager._arm_for_background()
	manager._on_player_turn_start()
	assert_eq(manager.turns_remaining, 1)
	assert_signal_emitted_with_parameters(Events, "hazard_countdown_changed", [hazard, 1])
	assert_signal_not_emitted(Events, "hazard_triggered")


func test_fires_at_zero_and_resets_to_the_interval() -> void:
	manager._arm_for_background()
	manager._on_player_turn_start()
	manager._on_player_turn_start()
	assert_signal_emitted_with_parameters(Events, "hazard_triggered", [hazard])
	assert_eq(manager.turns_remaining, 3, "counts down from turns_between after the first hit")


func test_a_turn_end_hazard_counts_turn_ends_not_turn_starts() -> void:
	hazard.timing = BackgroundHazardResource.Timing.YOUR_TURN_ENDS
	manager._arm_for_background()
	manager._on_player_turn_start()
	assert_eq(manager.turns_remaining, 2, "turn starts don't count for it")
	manager._on_enemy_turn_starting()
	assert_eq(manager.turns_remaining, 1)
	manager._on_enemy_turn_starting()
	assert_signal_emitted_with_parameters(Events, "hazard_triggered", [hazard])
	assert_eq(manager.turns_remaining, 3)


func test_a_turn_start_hazard_ignores_turn_ends() -> void:
	manager._arm_for_background()
	manager._on_enemy_turn_starting()
	assert_eq(manager.turns_remaining, 2)


func test_disarming_stops_the_countdown() -> void:
	manager._arm_for_background()
	manager._disarm()
	assert_false(manager.has_hazard())
	manager._on_player_turn_start()
	assert_signal_not_emitted(Events, "hazard_countdown_changed")
	assert_signal_not_emitted(Events, "hazard_triggered")
