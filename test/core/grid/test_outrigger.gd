extends "res://test/helpers/die_fighter_test.gd"
## The Outrigger: a hull gap drawn narrower than a tile, Feeds that cross it,
## and its two pods, whose thrust in step charges the drive (OutriggerSync).

const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const OUTRIGGER: ShipResource = preload("res://Source/Content/Ships/outrigger.tres")

var grid: TileGrid


## Two 3x3 pods at x 0..2 and 4..6, column 3 a hole drawn 12 px wide.
func _pod_grid(hole_width: int = 12) -> TileGrid:
	var pods: TileGrid = TileGrid.new()
	pods.position = Vector2(100, 50)
	pods.hole_column_width = hole_width
	pods.set_cells(OUTRIGGER.get_cells())
	add_child_autofree(pods)
	return pods


func _place(on: TileGrid, pos: Vector2i) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	on._assign_tile_to_grid_pos(tile, pos)
	return tile


# ── The hull gap ──────────────────────────────────────────────────────────────

func test_the_outrigger_is_two_pods_with_a_hole_between() -> void:
	var cells: Array[Vector2i] = OUTRIGGER.get_cells()
	assert_eq(cells.size(), 18)
	for y: int in 3:
		assert_false(cells.has(Vector2i(3, y)), "column 3 is the hull gap")


func test_a_narrow_gap_pulls_the_far_pod_in() -> void:
	grid = _pod_grid()
	var origin: Vector2 = grid.global_position
	# The port pod is untouched: 24 px columns from the origin.
	assert_eq(grid.grid_to_global_pos(Vector2i(0, 0)), origin + Vector2(12, 12))
	assert_eq(grid.grid_to_global_pos(Vector2i(2, 1)), origin + Vector2(60, 36))
	# The starboard pod starts 72 + 12 px along, not 96.
	assert_eq(grid.grid_to_global_pos(Vector2i(4, 0)), origin + Vector2(96, 12))
	assert_eq(grid.grid_to_global_pos(Vector2i(6, 2)), origin + Vector2(144, 60))


func test_cells_round_trip_through_pixels_across_the_gap() -> void:
	grid = _pod_grid()
	for cell: Vector2i in grid.get_cells():
		assert_eq(grid.global_pos_to_grid(grid.grid_to_global_pos(cell)), cell)


func test_a_drop_in_the_gap_lands_on_no_cell() -> void:
	grid = _pod_grid()
	var origin: Vector2 = grid.global_position
	var in_gap: Vector2i = grid.global_pos_to_grid(origin + Vector2(78, 30))
	assert_eq(in_gap, Vector2i(3, 1))
	assert_false(grid.is_grid_pos_valid(in_gap))
	# Edges: the last pixel of the port pod, the first of the starboard one.
	assert_eq(grid.global_pos_to_grid(origin + Vector2(71.9, 1)).x, 2)
	assert_eq(grid.global_pos_to_grid(origin + Vector2(84, 1)).x, 4)
	# Off the right-hand side still reads as off the grid.
	assert_eq(grid.global_pos_to_grid(origin + Vector2(156.5, 1)).x, 7)
	assert_eq(grid.global_pos_to_grid(origin + Vector2(-0.5, 1)).x, -1)


func test_without_a_gap_width_columns_stay_a_tile_wide() -> void:
	grid = _pod_grid(-1)
	assert_eq(grid.grid_to_global_pos(Vector2i(4, 0)), grid.global_position + Vector2(108, 12))


func test_the_ship_hands_its_gap_width_to_the_grid() -> void:
	Globals.selected_ship = OUTRIGGER
	grid = TileGrid.new()
	add_child_autofree(grid)
	assert_eq(grid.hole_column_width, 16)
	assert_eq(grid.grid_width, 7)


func test_nothing_crosses_the_gap_by_adjacency_or_push() -> void:
	grid = _pod_grid()
	var tile: Tile = _place(grid, Vector2i(2, 1))
	assert_false(grid.can_push_tile(tile, Vector2i(1, 0)))


# ── Feeding across ────────────────────────────────────────────────────────────

func test_cells_mirror_across_the_gap() -> void:
	grid = _pod_grid()
	assert_eq(grid.mirror_of(Vector2i(0, 1)), Vector2i(6, 1))
	assert_eq(grid.mirror_of(Vector2i(2, 0)), Vector2i(4, 0))
	assert_eq(grid.mirror_of(Vector2i(5, 2)), Vector2i(1, 2))


func test_the_mirrored_tile_is_targeted() -> void:
	grid = _pod_grid()
	Globals.tile_grid = grid
	var source: Tile = _place(grid, Vector2i(2, 1))
	var across: Tile = _place(grid, Vector2i(4, 1))
	var context: EffectContext = EffectContext.new()
	context.effect_source = source
	TargetMirroredTileHandler.new().apply(EffectData.new(), context, null)
	assert_eq(context.targets, [across] as Array[Node])


func test_an_empty_mirror_targets_nothing() -> void:
	grid = _pod_grid()
	Globals.tile_grid = grid
	var source: Tile = _place(grid, Vector2i(0, 0))
	var context: EffectContext = EffectContext.new()
	context.effect_source = source
	TargetMirroredTileHandler.new().apply(EffectData.new(), context, null)
	assert_true(context.targets.is_empty())


func test_a_centre_column_never_feeds_itself() -> void:
	grid = TileGrid.new()
	add_child_autofree(grid)
	Globals.tile_grid = grid
	var centre: Tile = _place(grid, Vector2i(2, 1))
	var context: EffectContext = EffectContext.new()
	context.effect_source = centre
	TargetMirroredTileHandler.new().apply(EffectData.new(), context, null)
	assert_true(context.targets.is_empty())


# ── Sync: the pods' thrust charges the drive ─────────────────────────────────

var sync: OutriggerSync


## A fight on the two-pod grid with the Outrigger's rules running, an engine
## to queue on, and a player at [param charge].
func _fight(charge: int = 0) -> void:
	grid = _pod_grid()
	Globals.tile_grid = grid
	var manager: GameStateManager = autofree(GameStateManager.new())
	manager.state = GameStateManager.GameState.IN_COMBAT
	Globals.state_manager = manager
	var scenarios: ScenarioManager = autofree(ScenarioManager.new())
	scenarios.engine = autofree(ScenarioEngine.new())
	Globals.scenario_manager = scenarios
	Globals.player = make_player(3, charge)
	sync = OutriggerSync.new()
	add_child_autofree(sync)


## [param face] activating [param tile], as TileActivationEvent announces it.
func _burn(tile: Tile, face: int) -> void:
	Events.tile_activated_by_die.emit(tile, face)
	Events.tile_activation_complete.emit()


func test_a_die_adds_its_face_to_its_tiles_pod() -> void:
	_fight()
	var port: Tile = _place(grid, Vector2i(1, 1))
	var starboard: Tile = _place(grid, Vector2i(6, 0))
	_burn(port, 4)
	_burn(port, 2)
	_burn(starboard, 5)
	assert_eq(sync.thrust(OutriggerSync.Pod.PORT), 6)
	assert_eq(sync.thrust(OutriggerSync.Pod.STARBOARD), 5)
	assert_eq(OutriggerSync.pod_of(Vector2i(3, 1), 7), OutriggerSync.Pod.NONE, "the hull gap is in no pod")
	Globals.state_manager.state = GameStateManager.GameState.OUT_OF_COMBAT
	_burn(port, 6)
	assert_eq(sync.thrust(OutriggerSync.Pod.PORT), 0, "out of a fight there's no thrust")


func test_the_turn_ends_charging_the_lower_pod_up_to_the_gate() -> void:
	_fight()
	var gate: int = Globals.player.max_engine_charge
	Globals.player.engine_charge = gate - 2
	_burn(_place(grid, Vector2i(0, 0)), 6)
	_burn(_place(grid, Vector2i(4, 0)), 4)
	Events.player_turn_over.emit()
	assert_eq(Globals.player.engine_charge, gate, "4 synced, 2 of it fits")
	assert_false(Globals.player.is_overcharged(), "syncing never redlines")
	assert_eq(OutriggerSync.charge_gain(6, 4, 0, gate), 4, "the lower pod's thrust")


func test_level_pods_are_announced_as_the_turn_ends() -> void:
	_fight()
	var port: Tile = _place(grid, Vector2i(2, 2))
	var starboard: Tile = _place(grid, Vector2i(4, 2))
	_burn(port, 5)
	_burn(starboard, 4)
	watch_signals(Events)
	Events.player_turn_over.emit()
	assert_signal_not_emitted(Events, "pods_level", "5 and 4 aren't level")
	Events.player_turn_refresh.emit()
	_burn(port, 3)
	_burn(starboard, 3)
	Events.player_turn_over.emit()
	assert_signal_emitted(Events, "pods_level")


func test_thrust_lasts_until_the_next_turn_starts() -> void:
	_fight()
	_burn(_place(grid, Vector2i(1, 0)), 4)
	_burn(_place(grid, Vector2i(5, 0)), 3)
	Events.player_turn_over.emit()
	var context: EffectContext = EffectContext.new()
	assert_eq(ShipRules.reading(OutriggerSync.READING_LEVEL, context), 3,
		"turn-end answers still read this turn's thrust")
	Events.player_turn_refresh.emit()
	assert_eq(sync.thrust(OutriggerSync.Pod.PORT), 0)
	assert_eq(sync.thrust(OutriggerSync.Pod.STARBOARD), 0)


func test_a_pods_lead_leaves_out_the_die_reading_it() -> void:
	_fight()
	var yaw: Tile = _place(grid, Vector2i(5, 1))
	_burn(_place(grid, Vector2i(4, 1)), 6)
	_burn(_place(grid, Vector2i(0, 1)), 2)
	var context: EffectContext = EffectContext.new()
	context.effect_source = yaw
	# The die lands on the tile: it adds thrust before the tile's chain reads
	# the lead, and the lead is what the gauge showed before it landed.
	Events.tile_activated_by_die.emit(yaw, 5)
	assert_eq(ShipRules.reading(OutriggerSync.READING_LEAD, context), 4)
	Events.tile_activation_complete.emit()
	assert_eq(ShipRules.reading(OutriggerSync.READING_LEAD, context), 9, "once it's done, it counts")
	context.effect_source = _place(grid, Vector2i(1, 1))
	assert_eq(ShipRules.reading(OutriggerSync.READING_LEAD, context), 0, "a pod behind leads by nothing")
