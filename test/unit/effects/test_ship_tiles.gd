extends "res://test/helpers/die_fighter_test.gd"
## The Outrigger's and Carousel's own tiles, each chain played whole through a
## recording engine: what Boost spends and buys, and what a tile's row does.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")

const SUNLANCE: TileResource = preload("res://Source/Content/Tiles/TileResources/sunlance.tres")
const SOLAR_SHROUD: TileResource = preload("res://Source/Content/Tiles/TileResources/solar_shroud.tres")
const APEX_CANNON: TileResource = preload("res://Source/Content/Tiles/TileResources/apex_cannon.tres")
const KEEL_PLATING: TileResource = preload("res://Source/Content/Tiles/TileResources/keel_plating.tres")
const FLYWHEEL: TileResource = preload("res://Source/Content/Tiles/TileResources/flywheel.tres")

var engine: RecordingEngine
var enemy: Enemy


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	enemy = autofree(ENEMY_SCENE.instantiate())
	enemy.health.max_health = 20
	enemy.health.health = 20
	enemy.scenario_state = ScenarioShipState.new()
	var computer: TargetingComputer = autofree(TargetingComputer.new())
	computer.targeted_enemy = enemy
	Globals.targeting_computer = computer


## Plays [param resource]'s chain from a tile at [param cell] on a 5x3 grid,
## with a die showing [param face], and returns what it produced.
func _play(resource: TileResource, face: int, charge: int = 0, cell: Vector2i = Vector2i(1, 1)) -> Array[EffectEvent]:
	Globals.player = make_player(3, charge)
	var grid: TileGrid = autofree(TileGrid.new())
	Globals.tile_grid = grid
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.sprite_frames = null
	tile.tile_resource = resource
	grid.tile_locations[cell] = tile
	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = face
	var context: EffectContext = EffectContext.new()
	context.effect_source = tile
	context.activator_die = die
	await resource.effect_chain.play(context, engine)
	return engine.injected


func _amounts(events: Array[EffectEvent], script: Script) -> Array[int]:
	var out: Array[int] = []
	for event: EffectEvent in events:
		if is_instance_of(event, script):
			out.append(event.amount)
	return out


func test_sunlance_spends_charge_to_set_the_target_burning() -> void:
	var events: Array[EffectEvent] = await _play(SUNLANCE, 4, 5)
	assert_eq(_amounts(events, DamageEvent), [4], "damage equal to die")
	assert_eq(_amounts(events, SpendEngineChargeEvent), [3])
	var burns: Array[EffectEvent] = engine.injected_of(ApplyStatusEvent)
	assert_eq(burns.size(), 1)
	if burns.size() == 1:
		assert_eq((burns[0] as ApplyStatusEvent).status_id, &"burn")
		assert_eq(burns[0].amount, 3)
		assert_eq(burns[0].targets, [enemy] as Array[Node2D], "the target burns, not the player")


func test_sunlance_without_the_charge_is_a_plain_cannon() -> void:
	var events: Array[EffectEvent] = await _play(SUNLANCE, 4, 2)
	assert_eq(_amounts(events, DamageEvent), [4])
	assert_eq(_amounts(events, SpendEngineChargeEvent), [], "can't afford it, pays nothing")
	assert_eq(engine.injected_of(ApplyStatusEvent).size(), 0)


func test_solar_shroud_doubles_with_boost() -> void:
	var boosted: Array[EffectEvent] = await _play(SOLAR_SHROUD, 2, 2)
	assert_eq(_amounts(boosted, ShieldEvent), [12])
	assert_eq(_amounts(boosted, SpendEngineChargeEvent), [2])
	engine.injected.clear()
	var plain: Array[EffectEvent] = await _play(SOLAR_SHROUD, 3, 1)
	assert_eq(_amounts(plain, ShieldEvent), [6])
	assert_eq(_amounts(plain, SpendEngineChargeEvent), [])


func test_apex_cannon_hits_harder_from_the_top_row() -> void:
	var top: Array[EffectEvent] = await _play(APEX_CANNON, 5, 0, Vector2i(2, 0))
	assert_eq(_amounts(top, DamageEvent), [8])
	engine.injected.clear()
	var middle: Array[EffectEvent] = await _play(APEX_CANNON, 5, 0, Vector2i(1, 1))
	assert_eq(_amounts(middle, DamageEvent), [5])


func test_keel_plating_doubles_from_the_bottom_row() -> void:
	var bottom: Array[EffectEvent] = await _play(KEEL_PLATING, 3, 0, Vector2i(3, 2))
	assert_eq(_amounts(bottom, ShieldEvent), [10])
	engine.injected.clear()
	var top: Array[EffectEvent] = await _play(KEEL_PLATING, 4, 0, Vector2i(3, 0))
	assert_eq(_amounts(top, ShieldEvent), [5])


func test_flywheel_spends_its_ring_steps_raising_the_die() -> void:
	Globals.player = make_player(3)
	var grid: TileGrid = autofree(TileGrid.new())
	Globals.tile_grid = grid
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.sprite_frames = null
	tile.tile_resource = FLYWHEEL
	tile.effect_data[CarouselBehavior.STEPS_KEY] = 2
	grid.tile_locations[Vector2i(0, 0)] = tile
	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = 1
	var context: EffectContext = EffectContext.new()
	context.effect_source = tile
	context.activator_die = die
	await FLYWHEEL.effect_chain.play(context, engine)
	assert_eq(_amounts(engine.injected, AddToActivatorValueEvent), [4], "2 per ring step")
	assert_eq(_amounts(engine.injected, SetTileDataEvent), [0], "the count resets to 0")
