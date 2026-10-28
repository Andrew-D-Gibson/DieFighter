extends "res://test/helpers/die_fighter_test.gd"
## ActivationResource checks that read game state rather than the die.


func _check(type: ActivationResource.ActivationType, threshold: int = 0) -> ActivationResource:
	var check := ActivationResource.new()
	check.type = type
	check.threshold = threshold
	return check


func test_dice_owned_at_most_is_inclusive() -> void:
	var check := _check(ActivationResource.ActivationType.DICE_OWNED_AT_MOST, 4)
	Globals.player = make_player(4)
	assert_true(check.criteria_satisfied(null))
	Globals.player = make_player(5)
	assert_false(check.criteria_satisfied(null))
	assert_eq(check.get_criteria_fail_text(), "TOO MANY DICE")


func test_dice_owned_at_most_refuses_without_a_player() -> void:
	Globals.player = null
	assert_false(_check(ActivationResource.ActivationType.DICE_OWNED_AT_MOST, 99).criteria_satisfied(null))


func test_shields_at_least_is_inclusive() -> void:
	var check := _check(ActivationResource.ActivationType.SHIELDS_AT_LEAST, 1)
	var player := make_player()
	player.health = add_child_autofree(Health.new())
	Globals.player = player
	assert_false(check.criteria_satisfied(null), "no shields, nothing to cash in")
	player.health.shields = 1
	assert_true(check.criteria_satisfied(null))
	assert_eq(check.get_criteria_fail_text(), "NOT ENOUGH SHIELDS")


func test_tile_data_at_least_reads_the_tile_asking() -> void:
	var check := _check(ActivationResource.ActivationType.TILE_DATA_AT_LEAST, 1)
	check.data_key = "ring_steps"
	var tile: Tile = autofree(Tile.new())
	assert_false(check.criteria_satisfied(null, tile), "no steps ridden yet")
	tile.effect_data["ring_steps"] = 1
	assert_true(check.criteria_satisfied(null, tile))
	assert_false(check.criteria_satisfied(null), "no tile to read")


func test_slingshot_refuses_a_die_before_the_ring_has_moved() -> void:
	var slingshot: TileResource = load("res://Source/Content/Tiles/TileResources/slingshot.tres")
	var gated: bool = slingshot.activation_checks.any(func(check: ActivationResource) -> bool:
		return check.type == ActivationResource.ActivationType.TILE_DATA_AT_LEAST \
			and check.data_key == CarouselBehavior.STEPS_KEY and check.threshold == 1
	)
	assert_true(gated, "a Slingshot fired at 0 steps would spend a die for nothing")
