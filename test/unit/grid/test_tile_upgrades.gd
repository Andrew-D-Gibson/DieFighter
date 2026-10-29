extends "res://test/helpers/die_fighter_test.gd"
## Tile upgrades: a copy of a tile dropped on its twin turns the twin into its
## upgraded version, and the authored upgrades are set up to allow it.

const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const TILES_DIR: String = "res://Source/Content/Tiles/TileResources/"
const DAMAGE: TileResource = preload("res://Source/Content/Tiles/TileResources/damage.tres")
const REROLL: TileResource = preload("res://Source/Content/Tiles/TileResources/reroll.tres")

var grid: TileGrid


func before_each() -> void:
	super()
	grid = TileGrid.new()
	add_child_autofree(grid)
	Globals.tile_grid = grid


func _tile(resource: TileResource) -> Tile:
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = resource
	return tile


func _on_grid(resource: TileResource, cell: Vector2i) -> Tile:
	var tile: Tile = _tile(resource)
	grid.add_child(tile)
	grid._assign_tile_to_grid_pos(tile, cell)
	return tile


## A copy on offer, in the tree the way a salvage choice is.
func _on_offer(resource: TileResource) -> Tile:
	var tile: Tile = _tile(resource)
	tile.on_offer = true
	add_child(tile)
	return tile


func _tiles_on_grid() -> Array[Tile]:
	var tiles: Array[Tile] = []
	for tile: Tile in grid.tile_locations.values():
		if is_instance_valid(tile) and not tile.is_queued_for_deletion():
			tiles.append(tile)
	return tiles


func test_every_upgrade_is_marked_and_held_out_of_offers() -> void:
	var found: int = 0
	for path: String in Utils.list_resource_paths(TILES_DIR):
		var base: TileResource = load(path) as TileResource
		if base == null or base.upgraded_version == null:
			continue
		found += 1
		var up: TileResource = base.upgraded_version
		assert_false(base.is_upgrade, "%s: a base tile isn't itself an upgrade" % path)
		assert_true(up.is_upgrade, "%s: its upgrade is marked" % path)
		assert_false(up.offered_as_reward, "%s: its upgrade is never offered" % path)
		assert_null(up.upgraded_version, "%s: an upgrade goes no further" % path)
		assert_ne(up.tile_name, base.tile_name, "%s: the upgrade is named apart" % path)
		var frames: int = up.textures.get_frame_count(&"default")
		assert_eq(frames, maxi(1, up.uses_per_turn + 1), "%s: one frame per light" % path)
	assert_gt(found, 0, "some tiles have upgrades")


func test_a_copy_dropped_on_its_twin_upgrades_it() -> void:
	var twin: Tile = _on_grid(DAMAGE, Vector2i(1, 1))
	var copy: Tile = _on_offer(DAMAGE)
	watch_signals(Events)
	grid.receive_tile(copy, grid.grid_to_global_pos(Vector2i(1, 1)))
	assert_eq(twin.tile_resource, DAMAGE.upgraded_version)
	assert_eq(_tiles_on_grid().size(), 1, "the copy is used up")
	assert_true(copy.is_queued_for_deletion())
	assert_signal_emitted_with_parameters(Events, "tile_upgraded", [twin])


func test_a_copy_dropped_elsewhere_is_a_second_tile() -> void:
	_on_grid(DAMAGE, Vector2i(1, 1))
	grid.receive_tile(_on_offer(DAMAGE), grid.grid_to_global_pos(Vector2i(2, 1)))
	assert_eq(_tiles_on_grid().size(), 2)
	for tile: Tile in _tiles_on_grid():
		assert_eq(tile.tile_resource, DAMAGE)


func test_an_upgraded_tile_takes_no_second_upgrade() -> void:
	var twin: Tile = _on_grid(DAMAGE, Vector2i(1, 1))
	twin.upgrade()
	var copy: Tile = _on_offer(DAMAGE)
	assert_null(grid.merge_target_at(copy, grid.grid_to_global_pos(Vector2i(1, 1))))
	grid.receive_tile(copy, grid.grid_to_global_pos(Vector2i(1, 1)))
	assert_eq(_tiles_on_grid().size(), 2, "it takes a cell of its own")


func test_a_different_tile_is_no_merge_target() -> void:
	_on_grid(DAMAGE, Vector2i(1, 1))
	var other: Tile = _on_offer(REROLL)
	assert_null(grid.merge_target_at(other, grid.grid_to_global_pos(Vector2i(1, 1))))
	other.free()


func test_two_copies_on_the_grid_merge() -> void:
	var kept: Tile = _on_grid(DAMAGE, Vector2i(1, 1))
	var moved: Tile = _on_grid(DAMAGE, Vector2i(3, 1))
	grid._drop_tile_on_grid_pos(moved.draggable, grid.grid_to_global_pos(Vector2i(1, 1)))
	assert_eq(kept.tile_resource, DAMAGE.upgraded_version)
	assert_eq(_tiles_on_grid().size(), 1)
	assert_true(grid.is_grid_pos_open(Vector2i(3, 1)), "the moved copy's cell is free")


func test_an_upgraded_tile_shimmers_and_sparks() -> void:
	var twin: Tile = _on_grid(DAMAGE, Vector2i(1, 1))
	var mat: ShaderMaterial = twin.sprite_frames.material as ShaderMaterial
	assert_false(mat.get_shader_parameter("upgraded"))
	twin.upgrade()
	assert_true(mat.get_shader_parameter("upgraded"))
	assert_not_null(twin.sprite_frames.get_node_or_null(^"UpgradeSparks"))


func test_an_upgrade_refills_uses_for_its_new_count() -> void:
	var twin: Tile = _on_grid(REROLL, Vector2i(1, 1))
	twin.uses_remaining = 0
	twin.upgrade()
	assert_eq(twin.uses_remaining, REROLL.upgraded_version.uses_per_turn)


func test_tiles_already_owned_are_still_offered() -> void:
	var rewards: RewardManager = add_child_autofree(RewardManager.new())
	_on_grid(DAMAGE, Vector2i(1, 1))
	assert_has(rewards.get_possible_tile_rewards(), DAMAGE)
	for offered: TileResource in rewards.get_possible_tile_rewards():
		assert_false(offered.is_upgrade, "%s: upgrades come only from merging" % offered.tile_name)
