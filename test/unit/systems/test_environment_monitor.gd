extends "res://test/helpers/die_fighter_test.gd"
## EnvironmentMonitor: swings up whenever the player arrives somewhere with a
## rule or a hazard, fight or no fight, and folds away for the jump out. A
## hazard's countdown shows only while a fight has it counting down.
##
## The monitor is in the tree, so it listens to the real Events; the signals
## the managers would send are emitted by hand. It answers a burst of them
## with one deferred present, so each step waits a frame before checking.

const MONITOR_SCENE: PackedScene = preload(
	"res://Source/Systems/Game/TargetingComputer/EnvironmentMonitor/environment_monitor.tscn"
)

var monitor: EnvironmentMonitor
var background: BackgroundResource
var hazard: BackgroundHazardResource


func before_each() -> void:
	super()
	hazard = BackgroundHazardResource.new()
	hazard.hazard_name = "Test Flare"
	hazard.turns_until_first = 3

	background = BackgroundResource.new()
	background.hazard = hazard
	var background_manager: BackgroundManager = autofree(BackgroundManager.new())
	background_manager.current_background = background
	Globals.background_manager = background_manager

	monitor = add_child_autofree(MONITOR_SCENE.instantiate())


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func test_arriving_in_a_hazard_region_shows_it_without_a_fight() -> void:
	Events.start_scenario.emit()
	await _settle()
	assert_true(monitor._deployed, "up on arrival, not only once a fight starts")
	assert_false(monitor._countdown.visible, "no countdown outside a fight")
	assert_true(monitor._unread)


func test_a_fight_adds_the_countdown_and_its_end_keeps_the_monitor_up() -> void:
	Events.start_scenario.emit()
	await _settle()

	Events.hazard_armed.emit(hazard, 3)
	await _settle()
	assert_true(monitor._countdown.visible)
	assert_eq(monitor._countdown.text, "3")

	Events.hazard_armed.emit(null, 0)
	await _settle()
	assert_true(monitor._deployed, "the region's hazard stays on show after the fight")
	assert_false(monitor._countdown.visible)


func test_reading_it_survives_a_fight_starting() -> void:
	Events.start_scenario.emit()
	await _settle()
	monitor._on_clicked()
	assert_false(monitor._unread)

	Events.hazard_armed.emit(hazard, 3)
	await _settle()
	assert_false(monitor._unread, "the same hazard, just counting now")


func test_nothing_shows_in_hyperspace() -> void:
	# A rule or a re-armed hazard can be announced while the jump is still
	# playing out: the new region's engine exists before arrival.
	var modifier: BackgroundModifierResource = BackgroundModifierResource.new()
	Events.background_modifier_applied.emit(modifier)
	Events.hazard_armed.emit(hazard, 3)
	await _settle()
	assert_false(monitor._deployed)


func test_the_jump_stows_it_and_the_next_arrival_announces_afresh() -> void:
	Events.start_scenario.emit()
	await _settle()
	monitor._on_clicked()

	Events.jump.emit()
	await _settle()
	assert_false(monitor._deployed)

	Events.start_scenario.emit()
	await _settle()
	assert_true(monitor._deployed)
	assert_true(monitor._unread, "a repeat of the same hazard is still a new arrival")


func test_plain_space_stays_folded_away() -> void:
	Globals.background_manager.current_background = BackgroundResource.new()
	Events.start_scenario.emit()
	Events.background_modifier_applied.emit(null)
	await _settle()
	assert_false(monitor._deployed)


func test_a_rule_region_shows_its_rule_on_arrival() -> void:
	Globals.background_manager.current_background = BackgroundResource.new()
	var modifier: BackgroundModifierResource = BackgroundModifierResource.new()
	Events.start_scenario.emit()
	Events.background_modifier_applied.emit(modifier)
	await _settle()
	assert_true(monitor._deployed)
	assert_eq(monitor._shown, modifier)
