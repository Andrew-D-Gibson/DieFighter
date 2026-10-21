extends "res://test/helpers/die_fighter_test.gd"
## PlayerHealthBar.shield_frame(): which shield sprite a shield total shows.
## Full from half the hull, medium from a quarter, low below that.


func test_half_the_hull_and_up_is_full() -> void:
	assert_eq(PlayerHealthBar.shield_frame(15, 30), PlayerHealthBar.SHIELD_FRAME_FULL)
	assert_eq(PlayerHealthBar.shield_frame(30, 30), PlayerHealthBar.SHIELD_FRAME_FULL)
	assert_eq(PlayerHealthBar.shield_frame(45, 30), PlayerHealthBar.SHIELD_FRAME_FULL)


func test_a_quarter_up_to_half_is_medium() -> void:
	assert_eq(PlayerHealthBar.shield_frame(14, 30), PlayerHealthBar.SHIELD_FRAME_MEDIUM)
	assert_eq(PlayerHealthBar.shield_frame(8, 30), PlayerHealthBar.SHIELD_FRAME_MEDIUM)


func test_under_a_quarter_is_low() -> void:
	assert_eq(PlayerHealthBar.shield_frame(7, 30), PlayerHealthBar.SHIELD_FRAME_LOW)
	assert_eq(PlayerHealthBar.shield_frame(1, 30), PlayerHealthBar.SHIELD_FRAME_LOW)


## An odd hull doesn't round a threshold down: 7.5 of 15 is half, so 7 is not.
func test_thresholds_are_not_rounded() -> void:
	assert_eq(PlayerHealthBar.shield_frame(8, 15), PlayerHealthBar.SHIELD_FRAME_FULL)
	assert_eq(PlayerHealthBar.shield_frame(7, 15), PlayerHealthBar.SHIELD_FRAME_MEDIUM)
	assert_eq(PlayerHealthBar.shield_frame(4, 15), PlayerHealthBar.SHIELD_FRAME_MEDIUM)
	assert_eq(PlayerHealthBar.shield_frame(3, 15), PlayerHealthBar.SHIELD_FRAME_LOW)
