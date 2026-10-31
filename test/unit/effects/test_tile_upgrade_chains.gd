extends "res://test/helpers/die_fighter_test.gd"
## Upgraded tiles play their chains whole and do what their text says, one
## of each kind of upgrade: a bigger number, an added "+N" step, a retarget,
## an effect bolted on, and a pair of steps that must cancel out.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const TILES: String = "res://Source/Content/Tiles/TileResources/%s.tres"

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
	# "All enemies" and "random enemy" read the roster.
	var roster: EnemyManager = autofree(EnemyManager.new())
	roster.enemies = [enemy] as Array[Enemy]
	Globals.enemy_manager = roster


func after_each() -> void:
	Globals.enemy_manager = null
	super()


## Plays [param tile_id]'s chain from (1, 1) of a 5x3 grid with a die showing
## [param face], and returns what it produced. [param neighbour] (a tile id),
## when given, sits at (2, 1).
func _play(tile_id: String, face: int, charge: int = 0, neighbour: String = "") -> Array[EffectEvent]:
	engine.injected.clear()
	var resource: TileResource = load(TILES % tile_id)
	Globals.player = make_player(3, charge)
	var grid: TileGrid = autofree(TileGrid.new())
	Globals.tile_grid = grid
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.sprite_frames = null
	tile.tile_resource = resource
	grid.tile_locations[Vector2i(1, 1)] = tile
	if neighbour != "":
		var beside: Tile = autofree(TILE_SCENE.instantiate())
		beside.sprite_frames = null
		beside.tile_resource = load(TILES % neighbour)
		grid.tile_locations[Vector2i(2, 1)] = beside
		grid.set_cells([Vector2i(1, 1), Vector2i(2, 1)] as Array[Vector2i])
	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = face
	var context: EffectContext = EffectContext.new()
	context.effect_source = tile
	context.activator_die = die
	await resource.effect_chain.play(context, engine)
	return engine.injected.duplicate()


func _amounts(events: Array[EffectEvent], script: Script) -> Array[int]:
	var out: Array[int] = []
	for event: EffectEvent in events:
		if is_instance_of(event, script):
			out.append(event.amount)
	return out


func test_dice_cannon_plus_adds_two_to_the_die() -> void:
	assert_eq(_amounts(await _play("damage", 4), DamageEvent), [4])
	assert_eq(_amounts(await _play("damage_plus", 4), DamageEvent), [6])


func test_ablative_charge_plus_hits_harder_and_costs_the_same() -> void:
	assert_eq(_amounts(await _play("ablative_charge_plus", 6), DamageEvent), [16, 3])


func test_target_painter_plus_exposes_by_die_plus_two() -> void:
	assert_eq(_amounts(await _play("target_painter", 3), ApplyStatusEvent), [3])
	assert_eq(_amounts(await _play("target_painter_plus", 3), ApplyStatusEvent), [5])


func test_chaos_explosion_plus_spares_the_player() -> void:
	var hits: Array[EffectEvent] = (await _play("chaos_explosion_plus", 6)).filter(
		func(e: EffectEvent) -> bool: return e is DamageEvent
	)
	assert_eq(hits.size(), 1)
	if hits.size() == 1:
		assert_eq(hits[0].amount, 10)
		assert_false(Globals.player in hits[0].targets, "the player isn't hit")
		assert_true(enemy in hits[0].targets)


func test_countermeasures_plus_also_shields_and_still_gives_the_die_to_target() -> void:
	var events: Array[EffectEvent] = await _play("countermeasures_plus", 2)
	var shields: Array[EffectEvent] = engine.injected_of(ShieldEvent)
	assert_eq(_amounts(events, ShieldEvent), [3])
	if shields.size() == 1:
		assert_eq(shields[0].targets, [Globals.player] as Array[Node2D])
	var gives: Array[EffectEvent] = engine.injected_of(GiveDieToTargetEvent)
	assert_eq(gives.size(), 1)
	if gives.size() == 1:
		assert_eq(gives[0].targets, [enemy] as Array[Node2D], "the die still goes to the target")


func test_emergency_transfer_plus_adds_four_shields_but_spends_only_the_charge() -> void:
	var events: Array[EffectEvent] = await _play("engines_to_shields_plus", 1, 5)
	assert_eq(_amounts(events, ShieldEvent), [9])
	assert_eq(_amounts(events, ChangeEngineChargeEvent), [-5])


func test_surge_relay_plus_rerolls_then_adds_one() -> void:
	var events: Array[EffectEvent] = await _play("surge_relay_plus", 3)
	assert_eq(engine.injected_of(RerollActivatorEvent).size(), 1)
	assert_eq(_amounts(events, AddToActivatorValueEvent), [1])


func test_grudge_cannon_plus_raises_its_plain_shot() -> void:
	assert_eq(_amounts(await _play("grudge_cannon_plus", 5), DamageEvent), [6])


func test_reloader_and_reloader_plus_give_surrounding_tiles_one_use() -> void:
	assert_eq(_amounts(await _play("reloader", 3, 0, "chain_cannon"), AddUsesRemainingEvent), [1])
	assert_eq(_amounts(await _play("reloader_plus", 3, 0, "chain_cannon"), AddUsesRemainingEvent), [1])
