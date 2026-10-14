extends "res://test/helpers/die_fighter_test.gd"
## EnemyFormation: where ships stand, given how wide they are and which parts
## of the screen are reserved, and which way each one should talk. Default
## usable span is x = 40..280; speech may use the whole 0..320.

var formation: EnemyFormation


func before_each() -> void:
	super()
	formation = EnemyFormation.new()


## [param count] ordinary 32px ships.
func _positions(count: int) -> Array:
	var widths := PackedFloat32Array()
	widths.resize(count)
	widths.fill(32.0)
	return Array(formation.solve(widths))


func test_no_ships_no_positions() -> void:
	assert_eq(_positions(0), [])


func test_one_ship_centres_itself() -> void:
	assert_eq(_positions(1), [160.0])


func test_a_wing_spreads_evenly() -> void:
	assert_eq(_positions(3), [80.0, 160.0, 240.0])


func test_a_pair_stands_well_apart() -> void:
	# Half gaps at the ends, so two ships get the middle of the screen between
	# them for their dice and speech rather than a third of it.
	assert_eq(_positions(2), [100.0, 220.0])


func test_a_wide_ship_does_not_swallow_its_escorts() -> void:
	var widths := PackedFloat32Array([32.0, 128.0, 32.0])
	var positions := formation.solve(widths)
	for i: int in range(1, positions.size()):
		var gap: float = (positions[i] - widths[i] * 0.5) - (positions[i - 1] + widths[i - 1] * 0.5)
		assert_true(gap >= formation.min_ship_gap, "hulls %d and %d keep clear" % [i - 1, i])


func test_a_reservation_squeezes_the_formation_aside() -> void:
	formation.reserve(&"shop", Vector2(200, 280))
	assert_eq(_positions(1), [120.0])


func test_the_widest_free_stretch_wins() -> void:
	formation.reserve(&"popup", Vector2(100, 140))
	assert_eq(formation.get_free_span(), Vector2(140, 280))


func test_a_pair_splits_around_a_reservation_in_the_middle() -> void:
	# Salvage floating mid-screen: one ship either side, each centred in its
	# half, rather than both crushed into one half.
	formation.reserve(&"reward", Vector2(110, 210))
	assert_eq(_positions(2), [75.0, 245.0])


func test_ships_keep_their_order_when_split() -> void:
	formation.reserve(&"reward", Vector2(150, 170))
	var positions := _positions(4)
	for i: int in range(1, positions.size()):
		assert_true(positions[i] > positions[i - 1], "ship %d stays right of ship %d" % [i, i - 1])
	assert_true(positions[1] < 150.0 and positions[2] > 170.0, "two each side")


func test_a_wing_stays_together_when_the_other_side_is_cramped() -> void:
	# 20px is no room for a 32px hull; both go right, even though that
	# side alone is narrower than the whole screen.
	formation.reserve(&"popup", Vector2(60, 100))
	var positions := _positions(2)
	assert_true(positions[0] > 100.0, "nobody squeezed into the sliver on the left")


func test_a_lone_ship_takes_the_wider_side() -> void:
	formation.reserve(&"popup", Vector2(100, 140))
	assert_eq(_positions(1), [210.0])


func test_clearing_a_reservation_restores_the_layout() -> void:
	formation.reserve(&"shop", Vector2(200, 280))
	formation.clear_reservation(&"shop")
	assert_eq(_positions(1), [160.0])


func test_reserve_reports_whether_anything_changed() -> void:
	assert_true(formation.reserve(&"shop", Vector2(200, 280)))
	assert_false(formation.reserve(&"shop", Vector2(280, 200)), "same span, either order")
	assert_true(formation.reserve(&"shop", Vector2(180, 280)))


func test_a_fully_reserved_screen_falls_back_to_the_whole_span() -> void:
	formation.reserve(&"everything", Vector2(0, 400))
	assert_eq(formation.get_free_span(), formation.usable_span)


func test_too_many_ships_keep_minimum_gap_rather_than_stacking() -> void:
	var positions := _positions(7)
	for i: int in range(1, positions.size()):
		assert_almost_eq(positions[i] - positions[i - 1], 32.0 + formation.min_ship_gap, 0.001)
	assert_true(positions[0] - 16.0 >= formation.usable_span.x, "the line stays on screen")


func test_a_lone_ship_talks_to_its_right() -> void:
	assert_false(formation.speech_points_left(160.0, PackedFloat32Array()))


func test_a_pair_talks_away_from_each_other() -> void:
	assert_true(formation.speech_points_left(100.0, PackedFloat32Array([220.0])), "left ship talks left")
	assert_false(formation.speech_points_left(220.0, PackedFloat32Array([100.0])), "right ship talks right")


func test_speech_turns_away_from_reserved_space() -> void:
	formation.reserve(&"shop", Vector2(200, 280))
	assert_true(formation.speech_points_left(160.0, PackedFloat32Array()))


func test_a_ship_is_not_crowded_by_its_own_pin() -> void:
	formation.reserve(&"ship_1", Vector2(140, 180))
	assert_false(formation.speech_points_left(160.0, PackedFloat32Array()))


## A ship whose health bar hangs 24px further out on its left than its 32px
## hull does, like the Venom Fighter's.
const _SIDE_BAR: Vector2 = Vector2(40.0, 16.0)


func _footprints(count: int, reach: Vector2) -> PackedVector2Array:
	var footprints := PackedVector2Array()
	for i: int in range(count):
		footprints.append(reach)
	return footprints


func test_a_health_bar_never_lands_on_the_next_hull() -> void:
	var footprints := _footprints(4, _SIDE_BAR)
	var positions := formation.solve_footprints(footprints)
	for i: int in range(1, positions.size()):
		var gap: float = (positions[i] - _SIDE_BAR.x) - (positions[i - 1] + _SIDE_BAR.y)
		assert_true(gap >= formation.min_ship_gap, "ship %d's bar clears ship %d" % [i, i - 1])


func test_a_lone_lopsided_ship_still_centres_its_hull() -> void:
	assert_eq(Array(formation.solve_footprints(_footprints(1, _SIDE_BAR))), [160.0])


func test_a_lone_ship_pressed_against_a_reservation_keeps_its_bar_clear() -> void:
	# The free stretch is 140..280; centring the hull at 210 would be fine, but
	# a stretch only just wide enough has to push the hull right of centre.
	formation.reserve(&"popup", Vector2(40, 226))
	var positions := formation.solve_footprints(_footprints(1, _SIDE_BAR))
	assert_true(positions[0] - _SIDE_BAR.x >= 226.0, "the bar stays off the reservation")


func test_symmetric_footprints_match_plain_widths() -> void:
	var widths := PackedFloat32Array([32.0, 128.0, 32.0])
	assert_eq(
		formation.solve_footprints(EnemyFormation.symmetric_footprints(widths)),
		formation.solve(widths)
	)


func test_fits_reports_a_crowd() -> void:
	assert_true(formation.fits(_footprints(3, _SIDE_BAR)))
	assert_false(formation.fits(_footprints(5, _SIDE_BAR)), "five side bars don't fit 240px")
	assert_true(formation.fits(_footprints(1, Vector2(400, 400))), "a lone ship always fits")
