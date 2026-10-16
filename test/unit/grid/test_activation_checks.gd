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
