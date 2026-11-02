extends "res://test/helpers/die_fighter_test.gd"
## The main menu's caravan: shrunk ships keep whole pixels in the art's own
## colours, the menu opens on a caravan already strung along its route, and a
## straggler is taken out of it and carried off.

const CARAVAN: PackedScene = preload("res://Source/Systems/UI/MainMenu/MenuCaravan/menu_caravan.tscn")

const PLANET_SHADER: Shader = preload("res://Assets/Shaders/pixel_planet.gdshader")

const _GREY: Color = Color("#A5A29D")
const _ORANGE: Color = Color("#F29C5D")


func test_shrinking_keeps_the_arts_own_colours() -> void:
	var art: Image = Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	art.fill_rect(Rect2i(0, 0, 8, 8), _GREY)
	art.fill_rect(Rect2i(0, 0, 4, 8), _ORANGE)
	var small: Image = PixelArtShrinker.shrink(art, 3)
	assert_eq(small.get_size(), Vector2i(3, 3))
	for y: int in 3:
		for x: int in 3:
			var c: Color = small.get_pixel(x, y)
			assert_true(c.is_equal_approx(_GREY) or c.is_equal_approx(_ORANGE),
				"pixel %d,%d is %s, not a colour from the art" % [x, y, c.to_html()])


func test_shrinking_drops_pixels_mostly_left_empty() -> void:
	var art: Image = Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	# One lone pixel in the top-left 4x4 block, a solid bottom-right block.
	art.set_pixel(0, 0, _GREY)
	art.fill_rect(Rect2i(4, 4, 4, 4), _ORANGE)
	var small: Image = PixelArtShrinker.shrink(art, 2)
	assert_eq(small.get_pixel(0, 0).a, 0.0, "a quarter-covered pixel stays empty")
	assert_true(small.get_pixel(1, 1).is_equal_approx(_ORANGE))


func test_flipping_turns_the_art_upside_down() -> void:
	var art: Image = Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	art.fill_rect(Rect2i(0, 0, 4, 2), _ORANGE)
	art.fill_rect(Rect2i(0, 2, 4, 2), _GREY)
	var small: Image = PixelArtShrinker.shrink(art, 2, true)
	assert_true(small.get_pixel(0, 0).is_equal_approx(_GREY))
	assert_true(small.get_pixel(0, 1).is_equal_approx(_ORANGE))


func test_the_menu_opens_on_a_caravan_already_underway() -> void:
	var caravan: MenuCaravan = _spawn_caravan()
	var ships: Array = caravan.get("_ships")
	assert_gt(ships.size(), 10, "the prewarm should fill the route")
	var length: float = caravan.route.curve.get_baked_length()
	var behind_from: float = caravan.get("_behind_from")
	var near: int = 0
	var far_side: int = 0
	for ship: MenuCaravan.Ship in ships:
		assert_between(ship.distance, 0.0, length)
		if ship.distance < behind_from:
			near += 1
		else:
			far_side += 1
	assert_gt(near, 0, "some ships are on the near side of the planet")
	assert_gt(far_side, 0, "some ships have looped behind it")


func after_each() -> void:
	Engine.time_scale = 1.0
	super()


func test_a_straggler_is_hooked_and_dragged_off_with_its_captor() -> void:
	var caravan: MenuCaravan = _spawn_caravan()
	var straggler: CaravanStraggler = caravan.get_node("Straggler")
	Engine.time_scale = 40.0
	# Wait for a ship to come into the stretch of route where they break down.
	await wait_until(func() -> bool: return straggler.call("_pick_straggler") != null, 20.0)
	var outcome: Dictionary = {}
	var run: Callable = func() -> void: outcome["taken"] = await straggler.play()
	run.call()
	var loose: Array[MenuCaravan.Ship] = _ships_off_route(caravan)
	assert_eq(loose.size(), 1, "the broken-down ship leaves the route")
	assert_has(straggler.breakdown_kinds, loose[0].kind)
	assert_eq(loose[0].beacon, MenuCaravan.Beacon.DISTRESS)

	await wait_until(func() -> bool: return _ships_off_route(caravan).size() == 2, 20.0)
	var raider: MenuCaravan.Ship = _ships_off_route(caravan).filter(
		func(ship: MenuCaravan.Ship) -> bool: return ship.kind == straggler.raider)[0]
	await wait_until(func() -> bool: return loose[0].beacon == MenuCaravan.Beacon.DARK, 20.0)
	assert_eq(loose[0].engine_power, 0.0, "the raider shoots its lights out")

	await wait_until(func() -> bool: return outcome.has("taken"), 30.0)
	assert_true(outcome.get("taken", false))
	assert_gt(raider.position.y, 180.0, "the raider drags it off the bottom of the screen")
	assert_eq(_ships_off_route(caravan).size(), 0, "both ships are gone")


func test_every_route_point_has_a_depth() -> void:
	var caravan: MenuCaravan = _spawn_caravan()
	assert_eq(caravan.point_depths.size(), caravan.route.curve.point_count)
	assert_lt(caravan.behind_planet_from_point, caravan.route.curve.point_count)


## The caravan next to a planet laid out like the main menu's.
func _spawn_caravan() -> MenuCaravan:
	var planet: ColorRect = ColorRect.new()
	planet.position = Vector2(184, -1)
	planet.size = Vector2(180, 180)
	var planet_material: ShaderMaterial = ShaderMaterial.new()
	planet_material.shader = PLANET_SHADER
	planet_material.set_shader_parameter("surface_radius", 0.383)
	planet.material = planet_material
	add_child_autofree(planet)
	var caravan: MenuCaravan = CARAVAN.instantiate()
	caravan.planet = planet
	# Tests that want a straggler start one themselves.
	caravan.get_node("Straggler").set("first_delay", Vector2(9999.0, 9999.0))
	add_child_autofree(caravan)
	return caravan


func _ships_off_route(caravan: MenuCaravan) -> Array[MenuCaravan.Ship]:
	var ships: Array[MenuCaravan.Ship] = caravan.get("_ships")
	return ships.filter(func(ship: MenuCaravan.Ship) -> bool: return not ship.on_route)
