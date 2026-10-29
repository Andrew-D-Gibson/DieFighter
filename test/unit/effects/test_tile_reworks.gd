extends "res://test/helpers/die_fighter_test.gd"
## Tiles reworked so playing them is a choice rather than free value, each
## chain played whole through a recording engine. What each one costs is the
## point: a tile that pays out for nothing is the thing these replaced.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")

const BALLAST_TANKS: TileResource = preload("res://Source/Content/Tiles/TileResources/ballast_tanks.tres")
const CROSSED_WIRES: TileResource = preload("res://Source/Content/Tiles/TileResources/crossed_wires.tres")
const STATIC_BLOOM: TileResource = preload("res://Source/Content/Tiles/TileResources/static_bloom.tres")
const SHIELD_BURST: TileResource = preload("res://Source/Content/Tiles/TileResources/shield.tres")

var engine: RecordingEngine
var enemy: Enemy
var grid: TileGrid


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
	Globals.player = make_player(3)
	grid = autofree(TileGrid.new())
	# The default rectangle, so Feeds can find the cell a tile sits in.
	grid.set_cells([] as Array[Vector2i])
	Globals.tile_grid = grid


func _place(resource: TileResource, cell: Vector2i) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.sprite_frames = null
	tile.tile_resource = resource
	grid.tile_locations[cell] = tile
	return tile


## Plays [param chain] from [param source] with a die showing [param face]
## (no die when [param face] is 0, as for a passive's event response).
func _play(chain: EffectChain, source: Tile, face: int = 0) -> Array[EffectEvent]:
	var context: EffectContext = EffectContext.new()
	context.effect_source = source
	if face > 0:
		var die: Dice = autofree(DICE_SCENE.instantiate())
		die.value = face
		context.activator_die = die
	await chain.play(context, engine)
	return engine.injected


func _amounts(script: Script) -> Array[int]:
	var out: Array[int] = []
	for event: EffectEvent in engine.injected_of(script):
		out.append(event.amount)
	return out


func test_ballast_tanks_trades_the_die_value_for_shields() -> void:
	var tanks: Tile = _place(BALLAST_TANKS, Vector2i(1, 1))
	await _play(BALLAST_TANKS.effect_chain, tanks, 5)
	assert_eq(_amounts(ShieldEvent), [5], "shields equal to die")
	assert_eq(_amounts(ChangeActivatorValueEvent), [1], "the die drops to a 1")


func test_ballast_tanks_feeds_the_tile_below() -> void:
	var tanks: Tile = _place(BALLAST_TANKS, Vector2i(1, 1))
	var below: Tile = _place(SHIELD_BURST, Vector2i(1, 2))
	_place(SHIELD_BURST, Vector2i(2, 1))
	await _play(BALLAST_TANKS.effect_chain, tanks, 6)
	var feeds: Array[EffectEvent] = engine.injected_of(PassDieToTileEvent)
	assert_eq(feeds.size(), 1)
	if feeds.size() == 1:
		assert_eq(feeds[0].targets, [below] as Array[Node2D], "down, not right")


func test_ballast_tanks_no_longer_hands_the_die_back() -> void:
	var tanks: Tile = _place(BALLAST_TANKS, Vector2i(1, 2))
	await _play(BALLAST_TANKS.effect_chain, tanks, 3)
	assert_eq(engine.injected_of(GiveDieToPlayerEvent).size(), 0)
	# The bottom row has nothing below: the Feed is still queued, and
	# PassDieToTileEvent sends the 1 to the target from there.
	assert_eq(engine.injected_of(PassDieToTileEvent).size(), 1)
	assert_eq(BALLAST_TANKS.uses_per_turn, 1, "a relay, so 1 or 2 uses")
	assert_eq(BALLAST_TANKS.textures.get_frame_count(&"default"), BALLAST_TANKS.uses_per_turn + 1)


func test_crossed_wires_spends_the_die_it_scrambles_with() -> void:
	var wires: Tile = _place(CROSSED_WIRES, Vector2i(0, 0))
	await _play(CROSSED_WIRES.effect_chain, wires, 6)
	var statuses: Array[EffectEvent] = engine.injected_of(ApplyStatusEvent)
	assert_eq(statuses.size(), 1)
	if statuses.size() == 1:
		assert_eq((statuses[0] as ApplyStatusEvent).status_id, &"scrambled")
		assert_eq(statuses[0].amount, 2)
		assert_eq(statuses[0].targets, [enemy] as Array[Node2D])
	assert_eq(engine.injected_of(GiveDieToPlayerEvent).size(), 0, "no free die back")
	var gives: Array[EffectEvent] = engine.injected_of(GiveDieToTargetEvent)
	assert_eq(gives.size(), 1)
	if gives.size() == 1:
		assert_eq(gives[0].targets, [enemy] as Array[Node2D])
	# Applied before the hand-off, so the given die arrives flipped and one
	# stack is left for the next.
	assert_lt(engine.injected.find(statuses[0]), engine.injected.find(gives[0]))


func test_static_bloom_scrambles_you_too() -> void:
	Globals.enemy_manager = autofree(EnemyManager.new())
	Globals.enemy_manager.enemies = [enemy] as Array[Enemy]
	var bloom: Tile = _place(STATIC_BLOOM, Vector2i(0, 0))
	var chain: EffectChain = STATIC_BLOOM.event_responses.values()[0]
	await _play(chain, bloom)
	var on_enemy: Array[int] = []
	var on_player: Array[int] = []
	for event: EffectEvent in engine.injected_of(ApplyStatusEvent):
		assert_eq((event as ApplyStatusEvent).status_id, &"scrambled")
		if event.targets.has(enemy):
			on_enemy.append(event.amount)
		elif event.targets.has(Globals.player):
			on_player.append(event.amount)
	assert_eq(on_enemy, [1])
	assert_eq(on_player, [1], "your first die this turn flips")
