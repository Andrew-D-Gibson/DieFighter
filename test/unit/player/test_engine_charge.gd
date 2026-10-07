extends "res://test/helpers/die_fighter_test.gd"
## Player engine charge: max from dice count, the redline band, and the two
## events that move charge (change vs. spend).


func test_max_charge_comes_from_the_dice_count() -> void:
	# (6 * (n - 1)) - floor(1.7078 * sqrt(n)); redline headroom is half of it.
	var expected: Dictionary = {3: 10, 5: 21, 6: 26}
	for dice: int in expected:
		var player := make_player(dice)
		assert_eq(player.max_engine_charge, expected[dice], "%d dice" % dice)
		assert_eq(player.overcharge_cap, roundi(expected[dice] * 0.5), "%d dice" % dice)


func test_charge_clamps_between_zero_and_the_redline_ceiling() -> void:
	var player := make_player(5)
	player.engine_charge = -5
	assert_eq(player.engine_charge, 0)
	player.engine_charge = 999
	assert_eq(player.engine_charge, player.charge_ceiling)


func test_losing_dice_reclamps_stranded_charge() -> void:
	var player := make_player(6)
	player.engine_charge = player.charge_ceiling
	player.num_of_dice = 3
	assert_eq(player.engine_charge, player.charge_ceiling)


func test_a_full_drive_that_loses_dice_stops_at_the_new_gate() -> void:
	# Dice left behind on a jump shrink the gate mid-flight. A drive sitting
	# at the old gate must not land in the redline and start bleeding hull.
	var player := make_player(3)
	player.engine_charge = player.max_engine_charge
	player.num_of_dice = 2
	assert_eq(player.engine_charge, player.max_engine_charge)
	assert_false(player.is_overcharged())


func test_a_single_die_still_has_a_positive_gate() -> void:
	# The curve goes negative at one die, which a jump can now leave the
	# player with; the engine bar divides by this.
	var player := make_player(1)
	assert_eq(player.max_engine_charge, 1)


func test_charge_queries() -> void:
	var player := make_player(5)
	player.engine_charge = player.max_engine_charge - 3
	assert_false(player.is_engine_charged())
	assert_eq(player.missing_charge(), 3)
	assert_eq(player.overcharge_amount(), 0)

	player.engine_charge = player.max_engine_charge + 2
	assert_true(player.is_engine_charged(), "redlined still counts as charged")
	assert_true(player.is_overcharged())
	assert_eq(player.missing_charge(), 0)
	assert_eq(player.overcharge_amount(), 2)


func test_can_afford_charge_is_inclusive() -> void:
	var player := make_player(5, 4)
	assert_true(player.can_afford_charge(4))
	assert_false(player.can_afford_charge(5))


# ── ChangeEngineChargeEvent ───────────────────────────────────────────────────

func _change(amount: int, allow_overcharge: bool = false) -> void:
	var event := ChangeEngineChargeEvent.new()
	event.amount = amount
	event.allow_overcharge = allow_overcharge
	event.resolve(null)


func test_ordinary_charge_gains_stop_at_the_gate() -> void:
	var player := make_player(5)
	Globals.player = player
	player.engine_charge = player.max_engine_charge - 1
	_change(6)
	assert_eq(player.engine_charge, player.max_engine_charge)


func test_overcharge_gains_may_enter_the_redline() -> void:
	var player := make_player(5)
	Globals.player = player
	player.engine_charge = player.max_engine_charge - 1
	_change(6, true)
	assert_eq(player.engine_charge, player.max_engine_charge + 5)


func test_the_player_spending_their_own_charge_is_not_a_drain() -> void:
	var player := make_player(5, 10)
	Globals.player = player
	watch_signals(Events)
	var event := ChangeEngineChargeEvent.new()
	event.amount = -4
	event.actor = player
	event.resolve(null)
	assert_eq(player.engine_charge, 6)
	assert_signal_not_emitted(Events, "engine_charge_drained")


# ── SpendEngineChargeEvent ────────────────────────────────────────────────────

func test_spending_deducts_the_price() -> void:
	var player := make_player(5, 10)
	Globals.player = player
	var event := SpendEngineChargeEvent.new()
	event.amount = 4
	event.resolve(null)
	assert_eq(player.engine_charge, 6)


func test_spending_more_than_you_have_refuses_instead_of_clamping() -> void:
	var player := make_player(5, 3)
	Globals.player = player
	var event := SpendEngineChargeEvent.new()
	event.amount = 4
	event.resolve(null)
	assert_eq(player.engine_charge, 3, "no free payoff")
	assert_push_warning("exceeds charge")
	assert_false(event.is_amplifiable(), "a price must never be amplified")
