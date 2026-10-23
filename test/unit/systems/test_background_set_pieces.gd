extends "res://test/helpers/die_fighter_test.gd"
## Planet and star layouts (SetPieceComposition) and the star parallax rule.

const BACKGROUND_ROOT: String = "res://Source/Resources/BackgroundResources/"
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
				var reach: float = _radius(object.scene) * (1.0 + object.size_jitter)
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


func test_zero_weight_is_never_picked() -> void:
	var never: SetPieceComposition = SetPieceComposition.new()
	never.weight = 0.0
	var always: SetPieceComposition = SetPieceComposition.new()
	var both: Array[SetPieceComposition] = [never, always]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for i: int in range(32):
		assert_eq(SetPieceComposition.pick(both, rng), always)


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
