extends "res://test/helpers/die_fighter_test.gd"
## The Outrigger: a hull gap drawn narrower than a tile, Feeds that cross it,
## and the sail that turns a kept hand into engine charge.

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


# ── The sail ──────────────────────────────────────────────────────────────────

func test_each_kept_die_adds_its_face() -> void:
	assert_eq(OutriggerSail.charge_plan([3, 4, 1] as Array[int], 0, 10), [3, 4, 1] as Array[int])


func test_the_sail_stops_at_the_jump_gate() -> void:
	assert_eq(OutriggerSail.charge_plan([6, 5, 2] as Array[int], 2, 10), [6, 2, 0] as Array[int])


func test_a_full_or_redlined_drive_takes_nothing() -> void:
	assert_eq(OutriggerSail.charge_plan([6] as Array[int], 10, 10), [0] as Array[int])
	assert_eq(OutriggerSail.charge_plan([6] as Array[int], 13, 10), [0] as Array[int])


func test_the_outrigger_may_end_a_turn_holding_dice() -> void:
	assert_true(OUTRIGGER.hand_may_be_kept)
	assert_false(ShipCatalog.find(ShipCatalog.DEFAULT_ID).hand_may_be_kept)


func test_a_sail_catch_never_redlines() -> void:
	Globals.player = make_player(3, 8)
	var event: ChangeEngineChargeEvent = ChangeEngineChargeEvent.new()
	event.amount = mini(6, Globals.player.missing_charge())
	event.resolve(null)
	assert_eq(Globals.player.engine_charge, Globals.player.max_engine_charge)
	assert_false(Globals.player.is_overcharged())


# ── Kept dice still go to the target ─────────────────────────────────────────

const SpyModifier := preload("res://test/helpers/spy_modifier.gd")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")


func _die(face: int) -> Dice:
	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = face
	return die


## Runs [param event] on a bare engine and returns every die hand-off it
## produced. The hand-offs are cancelled: there's no ship to receive them.
func _hand_offs_from(event: EffectEvent) -> Array[GiveDieToTargetEvent]:
	var engine: ScenarioEngine = autofree(ScenarioEngine.new())
	var given: Array[GiveDieToTargetEvent] = []
	var spy: Modifier = SpyModifier.new("spy", 0, [])
	spy.before = func(seen: EffectEvent, _engine: ScenarioEngine) -> void:
		if seen is GiveDieToTargetEvent:
			given.append(seen)
			seen.canceled = true
	engine.add_modifier(spy)
	engine.queue_event(event)
	return given


func test_a_die_the_full_sail_cannot_take_goes_to_the_target() -> void:
	Globals.player = make_player(3, 10)
	var die: Dice = _die(5)
	var catch: SailCatchEvent = SailCatchEvent.new()
	catch.activator_die = die
	catch.amount = 5
	var given: Array[GiveDieToTargetEvent] = _hand_offs_from(catch)
	assert_eq(given.size(), 1)
	assert_eq(given[0].activator_die, die)
	assert_eq(Globals.player.engine_charge, 10, "a full sail adds nothing")


func test_a_hand_off_carries_the_die_and_its_face() -> void:
	var die: Dice = _die(4)
	var give: GiveDieToTargetEvent = OutriggerSail.hand_off(die)
	assert_eq(give.activator_die, die)
	assert_eq(give.die_value, 4)
