extends "res://test/helpers/die_fighter_test.gd"
## The Carousel: its ring turns, carrying tiles round while the hub stays put,
## Gearbox data steers the next turn, and the Reactor's Feed is aimed at the
## ignition slot.

const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const BEHAVIOR_SCENE: PackedScene = preload("res://Source/Content/Ships/Carousel/carousel_behavior.tscn")
const CAROUSEL: ShipResource = preload("res://Source/Content/Ships/carousel.tres")
const CANNON: TileResource = preload("res://Source/Content/Tiles/TileResources/damage.tres")
const GEARBOX: TileResource = preload("res://Source/Content/Tiles/TileResources/gearbox.tres")
const SLINGSHOT: TileResource = preload("res://Source/Content/Tiles/TileResources/slingshot.tres")
const REACTOR: TileResource = preload("res://Source/Content/Ships/Carousel/reactor.tres")

var grid: TileGrid
var behavior: CarouselBehavior


func before_each() -> void:
	super()
	grid = TileGrid.new()
	grid.set_cells(CAROUSEL.get_cells())
	add_child_autofree(grid)
	behavior = BEHAVIOR_SCENE.instantiate()
	grid.add_child(behavior)


func _place(pos: Vector2i, resource: TileResource = CANNON) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.tile_resource = resource
	grid._assign_tile_to_grid_pos(tile, pos)
	return tile


func test_the_layout_is_a_ring_round_a_hub() -> void:
	var cells: Array[Vector2i] = CAROUSEL.get_cells()
	assert_eq(cells.size(), 14, "12 ring cells and 2 hub slots")
	assert_false(cells.has(CarouselBehavior.REACTOR_CELL), "the Reactor's cell is a hole")
	for cell: Vector2i in CarouselBehavior.RING + CarouselBehavior.HUB_SLOTS:
		assert_has(cells, cell)
	assert_has(CarouselBehavior.RING, CarouselBehavior.IGNITION_CELL)


func test_ring_cells_step_clockwise_and_wrap() -> void:
	assert_eq(CarouselBehavior.ring_cell_after(Vector2i(0, 0), 1), Vector2i(1, 0))
	assert_eq(CarouselBehavior.ring_cell_after(Vector2i(4, 0), 1), Vector2i(4, 1))
	assert_eq(CarouselBehavior.ring_cell_after(Vector2i(0, 1), 1), Vector2i(0, 0))
	assert_eq(CarouselBehavior.ring_cell_after(Vector2i(0, 0), -1), Vector2i(0, 1))
	assert_eq(CarouselBehavior.ring_cell_after(Vector2i(2, 0), 12), Vector2i(2, 0))
	assert_eq(CarouselBehavior.ring_cell_after(Vector2i(1, 1), 3), Vector2i(1, 1), "hub slots stay put")


func test_turning_carries_ring_tiles_and_leaves_the_hub() -> void:
	var on_ring: Tile = _place(Vector2i(4, 0))
	var behind_it: Tile = _place(Vector2i(3, 0))
	var in_hub: Tile = _place(Vector2i(1, 1))
	behavior._turn_ring(1, true)
	assert_eq(grid.find_tile_pos(on_ring), Vector2i(4, 1))
	assert_eq(grid.find_tile_pos(behind_it), Vector2i(4, 0), "a full ring shifts as one")
	assert_eq(grid.find_tile_pos(in_hub), Vector2i(1, 1))
	assert_eq(grid.tile_locations.size(), 3)


func test_a_full_ring_turns_without_losing_a_tile() -> void:
	var tiles: Dictionary[Vector2i, Tile] = {}
	for cell: Vector2i in CarouselBehavior.RING:
		tiles[cell] = _place(cell)
	behavior._turn_ring(1, true)
	for cell: Vector2i in tiles:
		assert_eq(grid.find_tile_pos(tiles[cell]), CarouselBehavior.ring_cell_after(cell, 1))
	assert_eq(grid.tile_locations.size(), 12)


func test_riding_the_ring_counts_steps() -> void:
	var sling: Tile = _place(Vector2i(0, 0), SLINGSHOT)
	var hub: Tile = _place(Vector2i(3, 1), SLINGSHOT)
	behavior._turn_ring(1, true)
	behavior._turn_ring(1, true)
	assert_eq(sling.effect_data.get(CarouselBehavior.STEPS_KEY, 0), 2)
	assert_eq(hub.effect_data.get(CarouselBehavior.STEPS_KEY, 0), 0, "the hub doesn't ride")
	behavior._on_fight_starts()
	assert_false(sling.effect_data.has(CarouselBehavior.STEPS_KEY), "a new fight starts the count over")


func test_the_ring_winds_home_the_short_way_after_a_fight() -> void:
	var tile: Tile = _place(Vector2i(1, 0))
	for i: int in 9:
		behavior._turn_ring(1, true)
	assert_eq(grid.find_tile_pos(tile), CarouselBehavior.ring_cell_after(Vector2i(1, 0), 9))
	behavior._wind_home()
	assert_eq(grid.find_tile_pos(tile), Vector2i(1, 0))
	assert_false(tile.effect_data.has(CarouselBehavior.STEPS_KEY), "winding home isn't riding")
	behavior._turn_ring(-2, true)
	behavior._wind_home()
	assert_eq(grid.find_tile_pos(tile), Vector2i(1, 0))


func test_gearbox_data_steers_the_next_turn() -> void:
	var gear: Tile = _place(Vector2i(3, 1), GEARBOX)
	var other: Tile = _place(Vector2i(1, 1), GEARBOX)
	assert_eq(behavior.pending_motion(), 1, "clockwise by default")
	gear.effect_data[CarouselBehavior.REVERSE_KEY] = 1
	assert_eq(behavior.pending_motion(), -1)
	other.effect_data[CarouselBehavior.HOLD_KEY] = 1
	assert_eq(behavior.pending_motion(), 0, "a hold beats a reverse")


func test_the_reactor_feeds_the_ignition_tile() -> void:
	var reactor: Tile = _place(Vector2i(1, 1), REACTOR)
	grid.forget_tile(reactor)
	behavior._reactor = reactor
	var mod := ReactorIgnitionModifier.new()
	mod.behavior = behavior

	var feed := PassDieToTileEvent.new()
	feed.effect_source = reactor
	mod.on_before_event(feed, null)
	assert_eq(feed.targets.size(), 0, "an empty slot: the die goes on to the target")

	var ignition: Tile = _place(CarouselBehavior.IGNITION_CELL)
	feed = PassDieToTileEvent.new()
	feed.effect_source = reactor
	mod.on_before_event(feed, null)
	assert_eq(feed.targets, [ignition] as Array[Node])

	var elsewhere := PassDieToTileEvent.new()
	elsewhere.effect_source = ignition
	var aimed: Array[Node] = [reactor]
	elsewhere.targets = aimed
	mod.on_before_event(elsewhere, null)
	assert_eq(elsewhere.targets, aimed, "other Feeds are left alone")


func test_carousel_tiles_follow_the_content_rules() -> void:
	assert_eq(GEARBOX.uses_per_turn, 1)
	assert_eq(GEARBOX.textures.get_frame_count(&"default"), GEARBOX.uses_per_turn + 1, "one light per use")
	assert_false(GEARBOX.offered_as_reward, "useless off the Carousel")
	assert_false(SLINGSHOT.offered_as_reward, "useless off the Carousel")
	assert_false(REACTOR.dragging_allowed)
	assert_false(REACTOR.can_be_locked_out, "it is the engine charger: never soft-lock it")


func test_a_locked_ignition_tile_only_takes_a_die_that_opens_it() -> void:
	var engine: ScenarioEngine = autofree(ScenarioEngine.new())
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = engine
	Globals.scenario_manager = manager
	var reactor: Tile = _place(Vector2i(1, 1), REACTOR)
	grid.forget_tile(reactor)
	behavior._reactor = reactor
	var ignition: Tile = _place(CarouselBehavior.IGNITION_CELL)
	assert_eq(behavior.feed_target_for(reactor, 5), ignition)
	engine.modifiers.append(LockoutModifier.new(ignition))
	assert_null(behavior.feed_target_for(reactor, 5),
		"a lock would bounce the die home: the Reactor would charge for free")
	assert_eq(behavior.feed_target_for(reactor, 2), ignition, "a low die opens the lock")
	assert_null(behavior.feed_target_for(ignition, 2), "only the Reactor's Feed is aimed")
