extends "res://test/helpers/die_fighter_test.gd"
## FateRiftTear: the breathing tear over rift_space. Checks it actually opens
## and closes on its own, stays inside its frame, holds wide for a strike and
## keeps the strike's blaze down under Reduce Flashing.

const TEAR_SCENE: PackedScene = preload("res://Source/Systems/Graphics/BackgroundManager/BackgroundObjects/FateRift/fate_rift_tear.tscn")

var tear: FateRiftTear


func before_each() -> void:
	super()
	Globals.reduce_flashing = false
	tear = add_child_autofree(TEAR_SCENE.instantiate())
	tear.set_process(false)


func after_each() -> void:
	Globals.reduce_flashing = false
	super()


func _run(seconds: float, step: float = 1.0 / 30.0) -> Dictionary:
	var lowest: float = INF
	var highest: float = -INF
	var phases: Dictionary[int, bool] = {}
	var steps: int = int(seconds / step)
	for i: int in range(steps):
		tear._process(step)
		lowest = minf(lowest, tear._open)
		highest = maxf(highest, tear._open)
		phases[tear._phase] = true
		assert_between(tear._reach, 0.0, 1.0)
	return {"lowest": lowest, "highest": highest, "phases": phases}


func test_it_breathes_open_and_shut_on_its_own() -> void:
	var seen: Dictionary = _run(40.0)
	assert_gt(seen.highest, tear.peak_open.x * 0.9, "opened up at least once")
	assert_lt(seen.lowest, tear.rest_open.y + 0.01, "closed back to a seam")
	for phase: int in FateRiftTear.Phase.values():
		assert_true(seen.phases.has(phase), "went through phase %d" % phase)


func test_the_open_tear_and_its_sparks_stay_inside_its_frame() -> void:
	var frame: Rect2 = Rect2(tear.get_node("Tear").position, tear.get_node("Tear").size)
	tear._fired()
	# Checked before stepping: a spark lives at most 0.6 s, so after the
	# 20 frames below the burst may all have burnt out.
	assert_gt(tear._sparks.size(), 0, "the strike threw sparks")
	for i: int in range(20):
		tear._process(1.0 / 30.0)
		for y: float in [-30.0, -10.0, 0.0, 10.0, 30.0]:
			var x: float = absf(FateRiftTear.spine_x(y)) + tear.lip_offset(y)
			assert_lt(x + 4.0, frame.size.x / 2.0, "lip at row %d fits with its glow" % y)


func test_the_build_up_holds_it_wide_until_the_strike() -> void:
	tear._winding_up(1.0)
	_run(6.0)
	assert_almost_eq(tear._open, 1.0, 0.01, "still torn wide, waiting")
	tear._fired()
	_run(0.2)
	assert_gt(tear._open, 1.0, "the strike rips it past fully open")
	var after: Dictionary = _run(10.0)
	assert_lt(after.lowest, 0.5, "and then it closes again")


func test_reduce_flashing_softens_the_strike_blaze() -> void:
	tear._fired()
	var full: float = tear._glow
	Globals.reduce_flashing = true
	tear._fired()
	assert_lt(tear._glow, full)
	assert_almost_eq(tear._glow, Juice.soften_flash(1.0), 0.001)
