extends "res://test/helpers/die_fighter_test.gd"
## IonStorm: the Ion Storm Front's lightning. Checks the photosensitivity
## guards (strikes spaced out, no full on-off strobe) and that both kinds of
## strike light the cloud from where the lightning is.

const STORM_SCENE: PackedScene = preload("res://Source/Systems/Graphics/BackgroundManager/BackgroundObjects/IonStorm/ion_storm.tscn")

var storm: IonStorm


func before_each() -> void:
	super()
	storm = add_child_autofree(STORM_SCENE.instantiate())
	storm.set_process(false)


func test_a_bolt_has_a_shape_and_lights_the_cloud_around_it() -> void:
	storm.strike_bolt()
	var strike: IonStorm.Strike = storm._strikes.back()
	assert_eq(strike.kind, IonStorm.Kind.BOLT)
	assert_gt(strike.bolt.core.size(), 10)
	assert_gt(strike.radius, 0.0)
	assert_almost_eq(storm._light(strike), 1.0, 0.001)


func test_an_unseen_strike_lights_the_cloud_from_off_screen() -> void:
	for i: int in range(20):
		storm.flash_offscreen()
		var centre: Vector2 = storm._strikes.back().centre
		var on_screen: bool = Rect2(Vector2.ZERO, Globals.SCREEN_SIZE).has_point(centre)
		assert_false(on_screen, "%s should be off screen" % centre)
	assert_null(storm._strikes.back().bolt)


func test_a_bolts_flicker_never_goes_fully_dark() -> void:
	storm.strike_bolt()
	var strike: IonStorm.Strike = storm._strikes.back()
	strike.age = (IonStorm._BOLT_BLINK.x + IonStorm._BOLT_BLINK.y) / 2.0
	assert_gte(storm._light(strike), 0.5)


func test_strikes_wait_out_the_minimum_gap() -> void:
	storm.strike_bolt()
	var first: IonStorm.Strike = storm._strikes.back()
	storm._countdown = 0.0
	storm._process(IonStorm.MIN_GAP * 0.6)
	assert_eq(storm._strikes.back(), first, "too soon after the last strike")
	storm._countdown = 0.0
	storm._process(IonStorm.MIN_GAP * 0.6)
	assert_false(storm._strikes.is_empty())
	assert_ne(storm._strikes.back(), first, "struck again once the gap had passed")


func test_imminence_shortens_the_wait() -> void:
	storm._countdown = 100.0
	storm.urgent = true
	storm._urgency_changed()
	assert_lte(storm._countdown, storm.urgent_gap.y)
	assert_gte(storm.urgent_gap.x, IonStorm.MIN_GAP, "urgent strikes stay at least MIN_GAP apart")


func test_spent_strikes_clear_away() -> void:
	storm.flash_offscreen()
	storm._process(2.0)
	assert_true(storm._strikes.is_empty())
