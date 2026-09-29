extends "res://test/helpers/die_fighter_test.gd"
## EnemyFormation: where ships stand, given how many there are and which parts
## of the screen are reserved. Default usable span is x = 40..280.

var formation: EnemyFormation


func before_each() -> void:
	super()
	formation = EnemyFormation.new()


func _positions(count: int) -> Array:
	return Array(formation.solve(count))


func test_no_ships_no_positions() -> void:
	assert_eq(_positions(0), [])


func test_one_ship_centres_itself() -> void:
	assert_eq(_positions(1), [160.0])


func test_a_wing_spreads_evenly() -> void:
	assert_eq(_positions(3), [100.0, 160.0, 220.0])


func test_a_reservation_squeezes_the_formation_aside() -> void:
	formation.reserve(&"shop", Vector2(200, 280))
	assert_eq(_positions(1), [120.0])


func test_the_widest_free_stretch_wins() -> void:
	formation.reserve(&"popup", Vector2(100, 140))
	assert_eq(formation.get_free_span(), Vector2(140, 280))


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


func test_too_many_ships_keep_minimum_spacing_rather_than_stacking() -> void:
	var positions := _positions(6)
	for i: int in range(1, positions.size()):
		assert_almost_eq(positions[i] - positions[i - 1], formation.min_ship_spacing, 0.001)
	assert_true(positions[0] >= formation.usable_span.x, "the line stays on screen")
