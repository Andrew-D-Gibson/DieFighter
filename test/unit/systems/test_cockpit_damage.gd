extends "res://test/helpers/die_fighter_test.gd"
## CockpitDamage: how many breaks show at a given hull. Spread evenly, so a
## full hull shows none, any damage at all starts showing them, and only zero
## hull shows every one.


func test_full_hull_shows_no_damage() -> void:
	assert_eq(CockpitDamage.sites_open_at(32, 32, 9), 0)


func test_zero_hull_shows_every_break() -> void:
	assert_eq(CockpitDamage.sites_open_at(0, 32, 9), 9)


func test_breaks_open_evenly_as_hull_drops() -> void:
	# Nine sites over 32 hull: one per tenth of the bar lost.
	assert_eq(CockpitDamage.sites_open_at(29, 32, 9), 0)
	assert_eq(CockpitDamage.sites_open_at(28, 32, 9), 1)
	assert_eq(CockpitDamage.sites_open_at(16, 32, 9), 5)
	assert_eq(CockpitDamage.sites_open_at(1, 32, 9), 9)


func test_count_never_falls_as_hull_drops() -> void:
	var previous: int = 0
	for hull: int in range(40, -1, -1):
		var open: int = CockpitDamage.sites_open_at(hull, 40, 9)
		assert_true(open >= previous, "hull %d opened fewer breaks than %d" % [hull, hull + 1])
		previous = open


func test_no_max_hull_shows_nothing() -> void:
	assert_eq(CockpitDamage.sites_open_at(0, 0, 9), 0)
