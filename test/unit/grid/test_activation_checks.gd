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
