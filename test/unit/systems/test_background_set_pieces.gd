extends "res://test/helpers/die_fighter_test.gd"
## Planet and star layouts (SetPieceComposition) and the star parallax rule.

const BACKGROUND_ROOT: String = "res://Source/Resources/BackgroundResources/"
const BODY_ROOT: String = "res://Source/Systems/Graphics/BackgroundManager/BackgroundObjects/CelestialBodies/"
## Art/_Palettes/aseprite_palette_final.aseprite, the approved colours.
const PALETTE: Array[String] = [
	"000000", "cef0f1", "d03656", "90263c", "511521", "43a6fc", "3789cc", "2c71aa",
	"7abd33", "659c2a", "4c7520", "eed35d", "ccb550", "98873b", "f29c5d", "ee7f2f",
	"bd580f", "c552f1", "a846ce", "80359d", "563226", "c4c1bc", "a5a29d", "8e8b85",
	"63605c", "343330", "8df1f4", "040217", "0f0c2e", "130f38", "191347", "251c6b",
	"463c91",
]
const MANAGER_SCENE: PackedScene = preload("res://Source/Systems/Graphics/BackgroundManager/background_manager.tscn")

## Where the ships fight: no set piece's disc may reach into this column, and
## its centre must sit in the upper band of the window, above the cockpit.
const ACTION_COLUMN: Vector2 = Vector2(112.0, 208.0)
const MAX_CENTRE_Y: float = 64.0
const MIN_CENTRE_Y: float = -24.0


func _backgrounds_with_compositions() -> Array[BackgroundResource]:
	var found: Array[BackgroundResource] = []
	for file: String in DirAccess.get_files_at(BACKGROUND_ROOT):
		if not file.ends_with(".tres"):
			continue
		var background: BackgroundResource = load(BACKGROUND_ROOT + file) as BackgroundResource
		if background and not background.set_piece_compositions.is_empty():
			found.append(background)
	return found


## Half the drawn width of a set piece scene: its Body rect if it has one.
func _radius(scene: PackedScene) -> float:
	var node: Node = scene.instantiate()
	var radius: float = 0.0
	var body: Control = node.get_node_or_null("Body") as Control
	if body:
		radius = (body.offset_right - body.offset_left) * 0.5
	node.free()
	return radius


func test_every_planet_background_has_several_layouts() -> void:
	var backgrounds: Array[BackgroundResource] = _backgrounds_with_compositions()
	assert_gte(backgrounds.size(), 7, "the seven planet backgrounds use compositions")
	for background: BackgroundResource in backgrounds:
		assert_gte(background.set_piece_compositions.size(), 3, background.resource_path)


func test_no_layout_reaches_the_action_column() -> void:
	for background: BackgroundResource in _backgrounds_with_compositions():
		for composition: SetPieceComposition in background.set_piece_compositions:
			for object: StaticBackgroundObjectResource in composition.objects:
				var widest: float = 0.0
				for scene: PackedScene in object.get_scene_choices():
					widest = maxf(widest, _radius(scene))
				var reach: float = widest * (1.0 + object.size_jitter)
				var slack: Vector2 = composition.offset_jitter + object.position_jitter
				var centres: Array[float] = [object.position.x]
				if composition.mirrorable:
					centres.append(Globals.SCREEN_SIZE.x - object.position.x)
				var label: String = "%s %s" % [background.resource_path.get_file(), object.scene.resource_path.get_file()]
				for x: float in centres:
					var left: float = x - slack.x - reach
					var right: float = x + slack.x + reach
					assert_true(right <= ACTION_COLUMN.x or left >= ACTION_COLUMN.y,
						"%s at x %d spans %d..%d" % [label, x, left, right])
				assert_lte(object.position.y + slack.y, MAX_CENTRE_Y, label)
				assert_gte(object.position.y - slack.y, MIN_CENTRE_Y, label)


func test_a_seed_always_lays_out_the_same_way() -> void:
	var background: BackgroundResource = load(BACKGROUND_ROOT + "blue_nebula.tres")
	var first: Array[Vector2] = _layout(background, 1234)
	var again: Array[Vector2] = _layout(background, 1234)
	assert_eq(again, first)


func test_different_seeds_vary_the_layout() -> void:
	var background: BackgroundResource = load(BACKGROUND_ROOT + "cryo_belt.tres")
	var seen: Dictionary[String, bool] = {}
	for i: int in range(8):
		seen[str(_layout(background, i))] = true
	assert_gt(seen.size(), 4, "eight seeds give at least five layouts")


func _layout(background: BackgroundResource, layout_seed: int) -> Array[Vector2]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = layout_seed
	var composition: SetPieceComposition = SetPieceComposition.pick(background.set_piece_compositions, rng)
	var positions: Array[Vector2] = []
	for placement: SetPieceComposition.Placement in composition.place(rng, Globals.SCREEN_SIZE.x):
		positions.append(placement.position)
	return positions


func test_mirroring_flips_position_and_light() -> void:
	var object: StaticBackgroundObjectResource = StaticBackgroundObjectResource.new()
	object.position = Vector2(40, 30)
	var composition: SetPieceComposition = SetPieceComposition.new()
	var objects: Array[StaticBackgroundObjectResource] = [object]
	composition.objects = objects
	composition.offset_jitter = Vector2.ZERO
	var mirrored_once: bool = false
	for i: int in range(16):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = i
		var placement: SetPieceComposition.Placement = composition.place(rng, 320.0)[0]
		if placement.mirrored:
			mirrored_once = true
			assert_eq(placement.position, Vector2(280, 30))
		else:
			assert_eq(placement.position, Vector2(40, 30))
	assert_true(mirrored_once)


func test_every_scene_variant_gets_drawn() -> void:
	var object: StaticBackgroundObjectResource = StaticBackgroundObjectResource.new()
	object.scene = load(BODY_ROOT + "blue_star.tscn")
	object.scene_variants = [load(BODY_ROOT + "amber_star.tscn"), load(BODY_ROOT + "white_dwarf.tscn")]
	var composition: SetPieceComposition = SetPieceComposition.new()
	var objects: Array[StaticBackgroundObjectResource] = [object]
	composition.objects = objects
	var seen: Dictionary[String, bool] = {}
	for i: int in range(32):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = i
		seen[composition.place(rng, 320.0)[0].scene.resource_path] = true
	assert_eq(seen.size(), 3, "the scene and both variants all turn up")


func test_a_piece_without_variants_shows_its_own_scene() -> void:
	var object: StaticBackgroundObjectResource = StaticBackgroundObjectResource.new()
	object.scene = load(BODY_ROOT + "blue_star.tscn")
	var composition: SetPieceComposition = SetPieceComposition.new()
	var objects: Array[StaticBackgroundObjectResource] = [object]
	composition.objects = objects
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	assert_eq(composition.place(rng, 320.0)[0].scene, object.scene)


func test_zero_weight_is_never_picked() -> void:
	var never: SetPieceComposition = SetPieceComposition.new()
	never.weight = 0.0
	var always: SetPieceComposition = SetPieceComposition.new()
	var both: Array[SetPieceComposition] = [never, always]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for i: int in range(32):
		assert_eq(SetPieceComposition.pick(both, rng), always)


# --- The plain star field ---------------------------------------------------

## What one visit to [param background] shows: the layout's name and its
## bodies, before jitter.
func _visit(background: BackgroundResource, visit_seed: int) -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = visit_seed
	var composition: SetPieceComposition = SetPieceComposition.pick(background.set_piece_compositions, rng)
	var parts: PackedStringArray = [str(background.set_piece_compositions.find(composition))]
	for placement: SetPieceComposition.Placement in composition.place(rng, Globals.SCREEN_SIZE.x):
		parts.append(placement.scene.resource_path.get_file())
	return " ".join(parts)


func test_star_field_rarely_repeats_its_bodies() -> void:
	var background: BackgroundResource = load(BACKGROUND_ROOT + "star_field.tres")
	var visits: Dictionary[String, int] = {}
	var bodies: Dictionary[String, bool] = {}
	for i: int in range(200):
		var visit: String = _visit(background, i)
		visits[visit] = visits.get(visit, 0) + 1
		for part: String in visit.split(" ").slice(1):
			bodies[part] = true
	assert_gte(visits.size(), 20, "200 visits show at least 20 different skies")
	for body: String in ["amber_star.tscn", "red_dwarf.tscn", "white_dwarf.tscn", "blue_star.tscn",
			"jade_world.tscn", "dune_world.tscn", "storm_giant.tscn"]:
		assert_true(bodies.has(body), "%s turns up" % body)
	for visit: String in visits:
		# Open space is the one sky allowed to come round often.
		if visit != str(background.set_piece_compositions.size() - 1):
			assert_lt(visits[visit], 25, "%s shows on %d of 200 visits" % [visit, visits[visit]])


## Every colour a palette texture on [param scene]'s body shader draws with.
func _shader_colours(scene: PackedScene) -> Array[Color]:
	var node: Node = scene.instantiate()
	var material: ShaderMaterial = (node.get_node("Body") as CanvasItem).material as ShaderMaterial
	var colours: Array[Color] = []
	for uniform: String in ["surface_palette", "atmosphere_palette", "cloud_1_palette", "cloud_2_palette"]:
		var texture: GradientTexture1D = material.get_shader_parameter(uniform) as GradientTexture1D
		if texture:
			colours.append_array(texture.gradient.colors)
	node.free()
	return colours


func test_star_field_draws_only_palette_colours() -> void:
	var background: BackgroundResource = load(BACKGROUND_ROOT + "star_field.tres")
	for tint: Color in background.star_tints:
		assert_has(PALETTE, tint.to_html(false), "star tint %s" % tint.to_html(false))
	for composition: SetPieceComposition in background.set_piece_compositions:
		for object: StaticBackgroundObjectResource in composition.objects:
			for scene: PackedScene in object.get_scene_choices():
				for colour: Color in _shader_colours(scene):
					assert_has(PALETTE, colour.to_html(false),
						"%s %s" % [scene.resource_path.get_file(), colour.to_html(false)])


func test_tinted_stars_take_a_tint_and_keep_their_depth_fade() -> void:
	var background: BackgroundResource = _open_sky()
	var tints: Array[Color] = [Color("eed35d"), Color("43a6fc")]
	background.star_tints = tints
	background.tinted_star_share = 1.0
	var manager: BackgroundManager = _manager(background)
	for star: Node2D in manager.stars:
		var colour: Color = star.modulate
		assert_true(tints.has(Color(colour.r, colour.g, colour.b)), "tinted %s" % colour)
		assert_between(colour.a, 0.25, 0.8)


func test_stars_stay_white_without_tints() -> void:
	var manager: BackgroundManager = _manager(_open_sky())
	for star: Node2D in manager.stars:
		var colour: Color = star.modulate
		assert_eq(Color(colour.r, colour.g, colour.b), Color.WHITE)


# --- Star parallax rule -----------------------------------------------------

func test_anything_on_screen_anchors_the_view() -> void:
	var debris: BackgroundResource = load(BACKGROUND_ROOT + "debris_field.tres")
	assert_true(debris.anchors_the_view(), "scrolling objects")
	var stars_only: BackgroundResource = load(BACKGROUND_ROOT + "star_field.tres")
	var planets: SetPieceComposition = stars_only.set_piece_compositions[0]
	assert_true(stars_only.anchors_the_view(planets), "a planet layout")
	var open: SetPieceComposition = SetPieceComposition.new()
	assert_false(stars_only.anchors_the_view(open), "an empty layout")
	assert_false(stars_only.anchors_the_view(null))


## A manager outside the tree: no _ready, so nothing connects to Events.
func _manager(background: BackgroundResource) -> BackgroundManager:
	var manager: BackgroundManager = autofree(MANAGER_SCENE.instantiate())
	manager._set_background(background)
	return manager


func _open_sky() -> BackgroundResource:
	var background: BackgroundResource = BackgroundResource.new()
	background.stars = true
	background.num_of_stars = 30
	return background


func _star_heights(manager: BackgroundManager) -> Array[float]:
	var heights: Array[float] = []
	for star: Node2D in manager.stars:
		heights.append(star.global_position.y)
	return heights


func test_stars_hold_at_rest_where_something_anchors_the_view() -> void:
	var background: BackgroundResource = _open_sky()
	background.scrolling_objects = load(BACKGROUND_ROOT + "ScrollingObjects/triangle_debris.tres")
	var manager: BackgroundManager = _manager(background)
	var before: Array[float] = _star_heights(manager)
	manager._move_stars(0.5)
	assert_eq(_star_heights(manager), before)


func test_anchored_stars_stream_once_a_jump_speeds_up() -> void:
	var background: BackgroundResource = _open_sky()
	background.scrolling_objects = load(BACKGROUND_ROOT + "ScrollingObjects/triangle_debris.tres")
	var manager: BackgroundManager = _manager(background)
	manager.global_speed = 320.0
	var before: Array[float] = _star_heights(manager)
	manager._move_stars(0.05)
	assert_ne(_star_heights(manager), before)


func test_open_sky_stars_drift_with_depth() -> void:
	var manager: BackgroundManager = _manager(_open_sky())
	var before: Array[float] = _star_heights(manager)
	manager._move_stars(0.1)
	var after: Array[float] = _star_heights(manager)
	for i: int in range(manager.stars.size()):
		var depth: float = manager.stars[i].get_meta("depth")
		var expected: float = manager._star_stream_speed() * depth * 0.1
		assert_almost_eq(after[i] - before[i], expected, 0.001)
	assert_gt(manager._star_stream_speed(), 0.0)


# --- Set pieces in a jump ---------------------------------------------------

## A sky holding one blue star at (40, 30), every time.
func _one_piece_sky() -> BackgroundResource:
	var object: StaticBackgroundObjectResource = StaticBackgroundObjectResource.new()
	object.scene = load(BODY_ROOT + "blue_star.tscn")
	object.position = Vector2(40, 30)
	var composition: SetPieceComposition = SetPieceComposition.new()
	var objects: Array[StaticBackgroundObjectResource] = [object]
	composition.objects = objects
	composition.offset_jitter = Vector2.ZERO
	composition.mirrorable = false
	var background: BackgroundResource = BackgroundResource.new()
	var compositions: Array[SetPieceComposition] = [composition]
	background.set_piece_compositions = compositions
	return background


func _piece_height(manager: BackgroundManager) -> float:
	return manager.static_objects[0].global_position.y


func test_set_pieces_hold_still_at_rest() -> void:
	var manager: BackgroundManager = _manager(_one_piece_sky())
	assert_eq(_piece_height(manager), 30.0)
	for i: int in range(10):
		manager._drift_static_objects(0.1)
	assert_eq(_piece_height(manager), 30.0)


func test_set_pieces_fall_away_faster_as_a_jump_speeds_up() -> void:
	var manager: BackgroundManager = _manager(_one_piece_sky())
	manager.global_speed = 160.0
	manager._drift_static_objects(0.5)
	var slow_fall: float = _piece_height(manager) - 30.0
	assert_gt(slow_fall, 0.0, "moves once the speed is up")
	manager.global_speed = 960.0
	var before: float = _piece_height(manager)
	manager._drift_static_objects(0.5)
	assert_gt(_piece_height(manager) - before, slow_fall, "falls faster as the jump builds")
	# Carried right off the bottom, and left there rather than wrapped round.
	for i: int in range(20):
		manager._drift_static_objects(0.5)
	assert_gt(_piece_height(manager), Globals.SCREEN_SIZE.y + 100.0)


func test_a_new_sky_loaded_mid_jump_settles_its_pieces_into_place() -> void:
	var manager: BackgroundManager = autofree(MANAGER_SCENE.instantiate())
	manager.global_speed = 960.0
	manager._set_background(_one_piece_sky())
	var height: float = _piece_height(manager)
	assert_lt(height, 30.0, "arrives from above")
	# The outro's slow-down, in steps.
	for i: int in range(1, 11):
		manager.global_speed = lerpf(960.0, manager._rest_speed, i / 10.0)
		manager._drift_static_objects(0.1)
		assert_gte(_piece_height(manager), height, "only ever moves down")
		height = _piece_height(manager)
	assert_eq(height, 30.0, "lands exactly where it was placed")
	manager._drift_static_objects(0.1)
	assert_eq(_piece_height(manager), 30.0, "and stays there")


# --- A scenario's pinned layout ---------------------------------------------

## The tutorial's two-ship fight pins its sky: the moon was authored to sit
## just right of the left ship's health bar (and clear of the lone survivor's
## once one ship falls), so no seed may move or mirror it.
func test_a_scenario_layout_is_shown_on_every_seed() -> void:
	var fight: ScenarioResource = load("res://Source/Content/ScenarioResources/Scenarios/COMBAT_TutorialPair/COMBAT_tutorial_pair.tres")
	var layout: SetPieceComposition = fight.set_piece_layout
	assert_not_null(layout)
	var expected: Array[Vector2] = []
	for object: StaticBackgroundObjectResource in layout.objects:
		expected.append(object.position)
	for layout_seed: int in range(6):
		RNGManager.seed_scenario(layout_seed)
		var manager: BackgroundManager = autofree(MANAGER_SCENE.instantiate())
		manager._set_background(fight.background_resource, true, layout)
		assert_eq(manager.current_composition, layout)
		var placed: Array[Vector2] = []
		for piece: Node2D in manager.static_objects:
			placed.append(piece.global_position)
		assert_eq(placed, expected, "seed %d" % layout_seed)
