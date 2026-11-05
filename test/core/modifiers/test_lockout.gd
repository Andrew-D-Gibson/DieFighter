extends "res://test/helpers/die_fighter_test.gd"
## Lockout: which tiles it may take hold on, that it never stacks, and how a
## locked tile explains itself in the info panel.

const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const ENGINE_CHARGER: TileResource = preload("res://Source/Content/Tiles/MapTileResources/engine_charger.tres")
const DAMAGE_TILE: TileResource = preload("res://Source/Content/Tiles/TileResources/damage.tres")
const LOCK_VISUAL: PackedScene = preload("res://Source/Behavior/Modifiers/LockoutModifier/lockout_modifier_visual.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const RecordingEngine = preload("res://test/helpers/recording_engine.gd")
const GRID_TILES_DIR: String = "res://Source/Content/Tiles/TileResources/"

var engine: ScenarioEngine


func before_each() -> void:
	super()
	engine = autofree(ScenarioEngine.new())
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = engine
	Globals.scenario_manager = manager


## A tile outside the tree carrying [param resource]. Its sprite is dropped
## first so assigning the resource doesn't start the gray-out tween, which
## needs the tree.
func _tile(resource: TileResource) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.sprite_frames = null
	tile.tile_resource = resource
	return tile


func _lock(targets: Array[Node]) -> void:
	var event: AddLockoutModifierEvent = AddLockoutModifierEvent.new()
	event.targets = targets
	await event.resolve(engine)


func _lockouts_on(tile: Tile) -> int:
	return engine.modifiers.filter(func(mod: Modifier) -> bool:
		return mod is LockoutModifier and mod.affected_node == tile
	).size()


# ── Who can be locked ─────────────────────────────────────────────────────────

func test_the_engine_charger_refuses_a_lockout() -> void:
	# Locking the only way to charge the drive could strand the player.
	var charger: Tile = _tile(ENGINE_CHARGER)
	var other: Tile = _tile(DAMAGE_TILE)
	await _lock([charger, other] as Array[Node])

	assert_false(charger.can_be_locked_out())
	assert_eq(_lockouts_on(charger), 0, "the Engine Charger is never locked")
	assert_eq(_lockouts_on(other), 1, "the rest of the lockout still lands")


func test_every_grid_tile_can_be_locked_out() -> void:
	# Random lockouts draw from the grid without asking, so a grid tile that
	# refused would make one fizzle. The Engine Charger lives off the grid.
	var dir: DirAccess = DirAccess.open(GRID_TILES_DIR)
	assert_not_null(dir)
	var checked: int = 0
	for file: String in dir.get_files():
		var path: String = file.trim_suffix(".remap")
		if not path.ends_with(".tres"):
			continue
		var resource: TileResource = load(GRID_TILES_DIR + path) as TileResource
		if resource == null:
			continue
		checked += 1
		assert_true(resource.can_be_locked_out, "%s can be locked out" % path)
	assert_gt(checked, 0)


# ── Lockouts never stack ──────────────────────────────────────────────────────

func test_a_second_lockout_on_a_locked_tile_is_refused() -> void:
	# Two locks would both fire on the die that opens the tile, handing it
	# out twice.
	var tile: Tile = _tile(DAMAGE_TILE)
	await _lock([tile] as Array[Node])
	assert_true(tile.is_locked_out())
	assert_false(tile.accepts_lockout())
	await _lock([tile] as Array[Node])
	assert_eq(_lockouts_on(tile), 1)


func test_one_lockout_naming_a_tile_twice_locks_it_once() -> void:
	var tile: Tile = _tile(DAMAGE_TILE)
	await _lock([tile, tile] as Array[Node])
	assert_eq(_lockouts_on(tile), 1)


## A grid holding [param tiles] in its first cells, as Globals.tile_grid.
func _grid_of(tiles: Array[Tile]) -> TileGrid:
	var grid: TileGrid = autofree(TileGrid.new())
	for i: int in tiles.size():
		grid.tile_locations[Vector2i(i, 0)] = tiles[i]
	Globals.tile_grid = grid
	return grid


func _pick_lockable() -> Array[Node]:
	var context: EffectContext = EffectContext.new()
	TargetRandomLockableTileHandler.new().apply(EffectData.new(), context, engine)
	return context.targets


func test_a_random_lockout_skips_locked_tiles() -> void:
	var locked: Tile = _tile(DAMAGE_TILE)
	var open: Tile = _tile(DAMAGE_TILE)
	_grid_of([locked, open] as Array[Tile])
	await _lock([locked] as Array[Node])
	for i: int in 20:
		assert_eq(_pick_lockable(), [open] as Array[Node], "only the open tile is drawn")


func test_a_random_lockout_skips_immune_tiles() -> void:
	var charger: Tile = _tile(ENGINE_CHARGER)
	var open: Tile = _tile(DAMAGE_TILE)
	_grid_of([charger, open] as Array[Tile])
	for i: int in 20:
		assert_eq(_pick_lockable(), [open] as Array[Node])


func test_a_random_lockout_with_every_tile_locked_targets_nothing() -> void:
	var first: Tile = _tile(DAMAGE_TILE)
	var second: Tile = _tile(DAMAGE_TILE)
	_grid_of([first, second] as Array[Tile])
	await _lock([first, second] as Array[Node])
	assert_eq(_pick_lockable(), [] as Array[Node])


func test_every_lockout_source_draws_a_lockable_tile() -> void:
	# A source still drawing from every tile could pick a locked one while an
	# open one is free, and the lock would fizzle on the backstop instead.
	for path: String in [
			"res://Source/Content/Enemies/EnemyActions/EnemyActionResources/lockout_grid_pos.tres",
			"res://Source/Content/BackgroundResources/BackgroundHazards/asteroid_impact.tres"]:
		var text: String = FileAccess.get_file_as_string(path)
		assert_string_contains(text, "subtype = %d\n" % EffectEnums.TargetingSubtype.TARGET_RANDOM_LOCKABLE_TILE, path)


# ── Opening a lock ────────────────────────────────────────────────────────────

func test_a_one_two_or_three_opens_a_lock() -> void:
	for face: int in range(1, 4):
		assert_true(LockoutModifier.unlocks(face), "a %d opens it" % face)
	for face: int in range(4, 7):
		assert_false(LockoutModifier.unlocks(face), "a %d is turned away" % face)


func test_a_locked_tile_refuses_four_or_higher_and_accepts_one_two_or_three() -> void:
	var tile: Tile = _tile(DAMAGE_TILE)
	await _lock([tile] as Array[Node])
	var low_die: Dice = autofree(DICE_SCENE.instantiate())
	low_die.value = 2
	var high_die: Dice = autofree(DICE_SCENE.instantiate())
	high_die.value = 5

	assert_eq(tile.activation_refusal(low_die, engine), "", "a low die opens the lock")
	assert_true(tile.clears_activation_criteria(low_die, engine))

	assert_eq(tile.activation_refusal(high_die, engine), tr("ERROR_TILE_LOCKED"))
	assert_false(tile.clears_activation_criteria(high_die, engine))


func test_a_feed_into_a_locked_tile_hands_off_a_four_or_higher_to_target() -> void:
	var recorder: RecordingEngine = autofree(RecordingEngine.new())
	var locked: Tile = _tile(DAMAGE_TILE)
	recorder.modifiers.append(LockoutModifier.new(locked))

	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = 5

	var feed: PassDieToTileEvent = PassDieToTileEvent.new()
	feed.activator_die = die
	feed.targets = [locked] as Array[Node]

	feed.resolve(recorder)

	var given: Array = recorder.injected_of(GiveDieToTargetEvent)
	assert_eq(given.size(), 1, "a 4+ fed into a locked tile goes on to the target")
	var activations: Array = recorder.injected_of(TileActivationEvent)
	assert_eq(activations.size(), 0, "no activation was injected for the locked tile")


func test_a_feed_into_a_locked_tile_passes_a_one_two_or_three() -> void:
	var recorder: RecordingEngine = autofree(RecordingEngine.new())
	var locked: Tile = _tile(DAMAGE_TILE)
	recorder.modifiers.append(LockoutModifier.new(locked))

	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = 2

	var feed: PassDieToTileEvent = PassDieToTileEvent.new()
	feed.activator_die = die
	feed.targets = [locked] as Array[Node]

	feed.resolve(recorder)

	var activations: Array = recorder.injected_of(TileActivationEvent)
	assert_eq(activations.size(), 1, "a 1-3 fed into a locked tile passes through to unlock it")
	assert_eq((activations[0] as TileActivationEvent).tile, locked)


# ── Tiles that never take a die ───────────────────────────────────────────────

func test_a_lock_stops_the_tiles_own_event_responses() -> void:
	# Napalm Vent and its kind act through event responses, not a die, so a
	# lock has to stop those too or it doesn't lock them at all.
	var locked: Tile = _tile(DAMAGE_TILE)
	var free: Tile = _tile(DAMAGE_TILE)
	var lock: LockoutModifier = LockoutModifier.new(locked)
	var on_locked: TileEventTriggeredEvent = TileEventTriggeredEvent.new()
	on_locked.responder = locked
	var on_free: TileEventTriggeredEvent = TileEventTriggeredEvent.new()
	on_free.responder = free

	lock.on_before_event(on_locked, engine)
	lock.on_before_event(on_free, engine)

	assert_true(on_locked.canceled, "the locked tile doesn't respond")
	assert_false(on_free.canceled, "other tiles still do")


# ── Info panel ────────────────────────────────────────────────────────────────

func test_locked_rule_is_not_duplicated_in_tile_info() -> void:
	var tile: Tile = _tile(DAMAGE_TILE)
	var original: String = tile._get_tile_info().bottom_label_text
	await _lock([tile] as Array[Node])
	assert_eq(tile._get_tile_info().bottom_label_text, original)
	assert_eq((LockoutModifier.new(tile)).get_info_text(), "")

func test_locked_is_a_hoverable_keyword() -> void:
	assert_string_contains(Keywords.definition("locked"), "unlocks")
	var rendered: String = Keywords.render("(locked) and (lock)", true)
	assert_string_contains(rendered, "[url=locked]")
	assert_false(rendered.contains("(lock"), "both spellings render")
