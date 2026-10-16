extends "res://test/helpers/die_fighter_test.gd"
## TimeDirector: overlapping hitstops and slow-mos share Engine.time_scale
## without one of them restoring full speed out from under another.
##
## Uses its own instance with a hand-stepped clock, never the autoload, and
## keeps it out of the tree so its _ready() doesn't hook the real Events.

## Advances only when a test says so, so expiry is exact and nothing sleeps.
class SteppedClockDirector extends "res://Source/Systems/Autoloads/time_director.gd":
	var now: int = 1000

	func _now_msec() -> int:
		return now


var director: SteppedClockDirector


func before_each() -> void:
	super()
	Engine.time_scale = 1.0
	director = autofree(SteppedClockDirector.new())


func after_each() -> void:
	# time_scale is engine-global; a leak would slow every test after this one.
	Engine.time_scale = 1.0
	super()


func _step(ms: int) -> void:
	director.now += ms
	director._process(0.0)


func test_slow_mo_sets_the_time_scale() -> void:
	director.slow_mo(0.3, 200)
	assert_almost_eq(Engine.time_scale, 0.3, 0.0001)


func test_slow_mo_ends_after_its_duration() -> void:
	director.slow_mo(0.3, 200)
	_step(199)
	assert_almost_eq(Engine.time_scale, 0.3, 0.0001, "still inside the window")
	_step(1)
	assert_eq(Engine.time_scale, 1.0)


func test_the_slowest_overlapping_request_wins() -> void:
	director.slow_mo(0.5, 300)
	director.slow_mo(0.2, 300)
	director.slow_mo(0.8, 300)
	assert_almost_eq(Engine.time_scale, 0.2, 0.0001)


func test_a_short_request_ending_does_not_cancel_a_longer_one() -> void:
	director.slow_mo(0.5, 500)
	director.slow_mo(0.1, 100)
	_step(150)
	assert_almost_eq(Engine.time_scale, 0.5, 0.0001,
		"the short slow-mo expired; the long one must still hold")
	_step(400)
	assert_eq(Engine.time_scale, 1.0)


func test_clear_restores_full_speed_and_drops_every_request() -> void:
	director.slow_mo(0.2, 1000)
	director.clear()
	assert_eq(Engine.time_scale, 1.0)
	_step(1)
	assert_eq(Engine.time_scale, 1.0, "a cleared request must not come back")


func test_requests_that_would_do_nothing_are_ignored() -> void:
	director.slow_mo(0.3, 0)
	director.slow_mo(1.0, 500)
	director.slow_mo(2.0, 500)
	assert_eq(Engine.time_scale, 1.0)
	assert_eq(director._requests.size(), 0)


func test_slow_mo_never_comes_to_a_full_stop() -> void:
	# A full stop is hitstop's job; slow-mo always keeps moving.
	director.slow_mo(0.0, 200)
	assert_gt(Engine.time_scale, 0.0)


func test_hitstop_freezes_time_completely() -> void:
	# hitstop() awaits a tree timer, and this director stays out of the tree,
	# so file the request it would make.
	director._add_request(director._HITSTOP_SCALE, 120)
	assert_eq(Engine.time_scale, 0.0)
	_step(120)
	assert_eq(Engine.time_scale, 1.0)


func test_hitstop_with_no_duration_does_nothing() -> void:
	await director.hitstop(0)
	assert_eq(Engine.time_scale, 1.0)
	assert_eq(director._requests.size(), 0)


func test_base_scale_sets_the_resting_speed() -> void:
	director.set_base_scale(0.5)
	assert_almost_eq(Engine.time_scale, 0.5, 0.0001)


func test_requests_slow_relative_to_the_base_scale() -> void:
	director.set_base_scale(0.5)
	director.slow_mo(0.4, 100)
	assert_almost_eq(Engine.time_scale, 0.2, 0.0001)
	_step(200)
	assert_almost_eq(Engine.time_scale, 0.5, 0.0001, "back to the base, not full speed")


func test_request_durations_stretch_with_the_base_scale() -> void:
	# At quarter speed everything should play four times as long, hitstops
	# included, or a slowed game still flashes past its impact frames.
	director.set_base_scale(0.25)
	director._add_request(director._HITSTOP_SCALE, 100)
	_step(399)
	assert_eq(Engine.time_scale, 0.0, "still frozen at 399 of 400 real ms")
	_step(1)
	assert_almost_eq(Engine.time_scale, 0.25, 0.0001)


func test_effect_time_runs_through_a_hitstop() -> void:
	_step(0)
	var start: float = director.effect_msec()
	director._add_request(director._HITSTOP_SCALE, 1000)
	_step(100)
	assert_almost_eq(director.effect_msec() - start, 100.0, 0.001)


func test_effect_time_runs_at_the_base_speed() -> void:
	_step(0)
	director.set_base_scale(0.25)
	var start: float = director.effect_msec()
	_step(100)
	assert_almost_eq(director.effect_msec() - start, 25.0, 0.001)


func test_clear_keeps_the_base_scale() -> void:
	director.set_base_scale(0.25)
	director.slow_mo(0.5, 1000)
	director.clear()
	assert_almost_eq(Engine.time_scale, 0.25, 0.0001)
