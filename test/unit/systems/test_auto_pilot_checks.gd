extends "res://test/helpers/die_fighter_test.gd"
## The AutoPilot's watchdogs: turn flow, leak warnings and error capture. The
## board checks read the live game and are exercised by tools/autoplay.sh.


func test_an_enemy_turn_starting_on_top_of_another_is_a_violation() -> void:
	var checks: AutoPilotInvariants = AutoPilotInvariants.new()
	assert_eq(checks.on_enemy_turn_starting().size(), 0)
	var broken: Array[Dictionary] = checks.on_enemy_turn_starting()
	assert_eq(broken.size(), 1)
	assert_eq(broken[0]["check"], "overlapping_enemy_turns")


func test_an_enemy_turn_after_the_last_one_ended_is_fine() -> void:
	var checks: AutoPilotInvariants = AutoPilotInvariants.new()
	checks.on_enemy_turn_starting()
	checks.on_enemy_turn_over()
	assert_eq(checks.on_enemy_turn_starting().size(), 0)


func test_a_new_fight_starts_the_turns_over() -> void:
	var checks: AutoPilotInvariants = AutoPilotInvariants.new()
	checks.on_enemy_turn_starting()
	checks.reset_turns()
	assert_eq(checks.on_enemy_turn_starting().size(), 0)


func test_memory_growth_warns_once_past_the_limit() -> void:
	var checks: AutoPilotInvariants = AutoPilotInvariants.new()
	assert_eq(checks.leaks({"nodes": 1000, "orphans": 0}).size(), 0, "the first arrival is the baseline")
	assert_eq(checks.leaks({"nodes": 1100, "orphans": 0}).size(), 0, "a scenario's own clutter")
	assert_eq(checks.leaks({"nodes": 1400, "orphans": 0}), ["nodes_growing"] as Array[String])
	assert_eq(checks.leaks({"nodes": 1600, "orphans": 0}).size(), 0, "named once per run")


func test_the_error_log_hands_over_what_it_caught_once() -> void:
	var error_log: AutoPilotErrorLog = AutoPilotErrorLog.new()
	var none: Array[ScriptBacktrace] = []
	error_log._log_error("apply", "res://x.gd", 12, "", "boom", false, Logger.ERROR_TYPE_SCRIPT, none)
	var caught: Array[Dictionary] = error_log.take()
	assert_eq(caught.size(), 1)
	assert_eq(caught[0]["kind"], "script")
	assert_eq(caught[0]["at"], "res://x.gd:12 apply")
	assert_eq(error_log.take().size(), 0)


func test_the_error_log_skips_warnings() -> void:
	var error_log: AutoPilotErrorLog = AutoPilotErrorLog.new()
	var none: Array[ScriptBacktrace] = []
	error_log._log_error("f", "x.gd", 1, "", "careful", false, Logger.ERROR_TYPE_WARNING, none)
	assert_eq(error_log.take().size(), 0)


func test_the_error_log_masks_what_differs_between_runs() -> void:
	# Two runs of one seed must write the same transcript.
	var error_log: AutoPilotErrorLog = AutoPilotErrorLog.new()
	var none: Array[ScriptBacktrace] = []
	error_log._log_error("f", "x.gd", 1, "", "Object 0x7f3a2b at <Node2D#123456789> is freed", false,
		Logger.ERROR_TYPE_ERROR, none)
	assert_eq(error_log.take()[0]["message"], "Object # at # is freed")
