extends "res://test/helpers/die_fighter_test.gd"
## JumpFx, the jump drive's look shared by the opening cutscene and departing
## ships. The cutscene must look as it did before the extraction, so the
## geometry is pinned to what the cutscene used to draw by hand.

var layer: Node2D
var fx: JumpFx


func before_each() -> void:
	super()
	layer = add_child_autofree(Node2D.new())
	fx = JumpFx.new(layer, true)


func _ship_at(spot: Vector2) -> Sprite2D:
	var ship: Sprite2D = Sprite2D.new()
	layer.add_child(ship)
	ship.global_position = spot
	return ship


func _streak_line() -> ColorRect:
	for holder: Node in layer.get_children():
		for child: Node in holder.get_children():
			if child is ColorRect:
				return child as ColorRect
	return null


func test_a_streak_right_is_the_cutscene_s_old_bar() -> void:
	# The cutscene drew a ColorRect at (min x, y - 1.5), |dx| long and 3 tall.
	fx.streak(Vector2(100, 60), Vector2(328, 60), Globals.red)
	var line: ColorRect = _streak_line()
	assert_not_null(line)
	assert_eq(line.rotation, 0.0)
	assert_eq(line.size, Vector2(228, 3))
	assert_eq(line.get_global_rect().position, Vector2(100, 58.5))


func test_a_jump_out_streaks_to_the_screen_edge_along_its_heading() -> void:
	var ship: Sprite2D = _ship_at(Vector2(84, 44))
	fx.jump_out(ship, JumpFx.RED, Vector2.RIGHT)
	var line: ColorRect = _streak_line()
	assert_eq(line.get_global_rect().position, Vector2(84, 42.5), "from the ship")
	assert_almost_eq(line.size.x, Globals.SCREEN_SIZE.x + 8.0 - 84.0, 0.001, "to just past the right edge")


func test_a_jump_up_streaks_off_the_top() -> void:
	var ship: Sprite2D = _ship_at(Vector2(160, 40))
	fx.jump_out(ship, JumpFx.RED, Vector2.UP)
	var line: ColorRect = _streak_line()
	assert_almost_eq(line.size.x, 48.0, 0.001, "40 up, plus the margin")
	assert_almost_eq(line.rotation, -PI / 2.0, 0.001)
	var holder: Node2D = line.get_parent() as Node2D
	assert_almost_eq(holder.global_position, Vector2(160, 16), Vector2.ONE * 0.001, "centred between ship and edge")


func test_the_stretch_lets_go_after_its_hold() -> void:
	var ship: Sprite2D = _ship_at(Vector2(50, 50))
	fx.jump_out(ship, JumpFx.BLUE, Vector2.RIGHT)
	await wait_seconds(JumpFx.STRETCH_SECONDS + 0.03)
	assert_almost_eq(ship.scale, JumpFx.STRETCH, Vector2.ONE * 0.05, "stretched")
	await wait_seconds(JumpFx.STRETCH_HOLD_SECONDS + 0.05)
	assert_eq(ship.scale, Vector2.ONE, "and back")


func test_the_charge_motes_stop_when_the_charge_does() -> void:
	var ship: Sprite2D = _ship_at(Vector2(50, 50))
	fx.charge(ship, 0.2, JumpFx.BLUE)
	var motes: CPUParticles2D = null
	for child: Node in ship.get_children():
		if child is CPUParticles2D:
			motes = child as CPUParticles2D
	assert_not_null(motes)
	assert_true(motes.emitting)
	await wait_seconds(0.25)
	assert_false(motes.emitting)


func test_off_the_art_grid_the_streak_draws_through_a_pixel_view() -> void:
	var game_fx: JumpFx = JumpFx.new(layer)
	game_fx.streak(Vector2(10, 10), Vector2(10, -8), Globals.red)
	var wrapped: bool = false
	for child: Node in layer.get_children():
		wrapped = wrapped or child is JuicePixelated
	assert_true(wrapped)
