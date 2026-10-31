extends "res://test/helpers/die_fighter_test.gd"
## Red tiles that must refuse a die, or stay quiet, rather than waste it or
## hit the wrong ship: Debt Collector needs dice on its target, Relay
## Terminal takes a 4-6, and the passives that answer a neighbour (Spark
## Gap, Napalm Vent) do nothing outside a fight, where the "enemy" could be a
## merchant.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const TILES: String = "res://Source/Content/Tiles/TileResources/%s.tres"

var engine: RecordingEngine
var player: Player
var enemy: Enemy


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = engine
	Globals.scenario_manager = manager
	player = add_child_autofree(PLAYER_SCENE.instantiate())
	Globals.player = player
	enemy = ENEMY_SCENE.instantiate()
	enemy.scenario_state = ScenarioShipState.new()
	enemy.scenario_state.attitude = Enemy.Attitude.AGGRESSIVE
	add_child_autofree(enemy)
	# A ship at 0 hull drops off the roster "random enemy" picks from.
	enemy.health.max_health = 40
	enemy.health.health = 40
	var computer: TargetingComputer = autofree(TargetingComputer.new())
	computer.targeted_enemy = enemy
	Globals.targeting_computer = computer
	var roster: EnemyManager = autofree(EnemyManager.new())
	roster.enemies = [enemy] as Array[Enemy]
	Globals.enemy_manager = roster
	Globals.tile_grid = autofree(TileGrid.new())
	var state: GameStateManager = autofree(GameStateManager.new())
	state.state = GameStateManager.GameState.IN_COMBAT
	Globals.state_manager = state


func after_each() -> void:
	Globals.enemy_manager = null
	super()


func _tile(tile_id: String) -> Tile:
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = load(TILES % tile_id)
	add_child_autofree(tile)
	return tile


## A die in the player's hand.
func _die(face: int) -> Dice:
	var die: Dice = DICE_SCENE.instantiate()
	die.value = face
	player.add_child(die)
	player.dice_manager.add(die)
	return die


## A die the enemy is already holding.
func _held(face: int) -> void:
	var die: Dice = _die(face)
	enemy.dice_manager.add(die)
	TractorBeam.release(die)


func _play(chain: EffectChain, tile: Tile, die: Dice = null) -> Array[EffectEvent]:
	engine.injected.clear()
	var context: EffectContext = EffectContext.new()
	context.actor = player
	context.effect_source = tile
	context.activator_die = die
	await chain.play(context, engine)
	return engine.injected.duplicate()


## Plays the one event response [param tile_id] has.
func _respond(tile_id: String) -> Array[EffectEvent]:
	var tile: Tile = _tile(tile_id)
	Globals.tile_grid.tile_locations[Vector2i(1, 1)] = tile
	var chains: Array = tile.tile_resource.event_responses.values()
	assert_eq(chains.size(), 1)
	return await _play(chains[0], tile)


func _damage(events: Array[EffectEvent]) -> Array[int]:
	var out: Array[int] = []
	for event: EffectEvent in events:
		if event is DamageEvent:
			out.append(event.amount)
	return out


# ── Debt Collector ────────────────────────────────────────────────────────────

func test_debt_collector_refuses_while_the_target_holds_no_dice() -> void:
	var tile: Tile = _tile("debt_collector")
	assert_ne(tile.activation_refusal(_die(3)), "", "nothing to collect on")
	_held(1)
	assert_eq(tile.activation_refusal(_die(3)), "")


func test_debt_collector_hits_four_per_die_the_target_holds() -> void:
	_held(2)
	_held(5)
	var tile: Tile = _tile("debt_collector")
	assert_eq(_damage(await _play(tile.tile_resource.effect_chain, tile, _die(3))), [8])


# ── Relay Terminal ────────────────────────────────────────────────────────────

func test_relay_terminal_takes_a_four_to_six() -> void:
	var tile: Tile = _tile("relay_terminal")
	for face: int in range(1, 4):
		assert_ne(tile.activation_refusal(_die(face)), "", "a %d is turned away" % face)
	for face: int in range(4, 7):
		assert_eq(tile.activation_refusal(_die(face)), "", "a %d is taken" % face)


# ── Neighbour passives ────────────────────────────────────────────────────────

func test_spark_gap_zaps_for_two_in_a_fight() -> void:
	assert_eq(_damage(await _respond("spark_gap")), [2])
	assert_eq(_damage(await _respond("spark_gap_plus")), [3])


func test_spark_gap_stays_quiet_outside_a_fight() -> void:
	# A fresh manager starts out of combat.
	Globals.state_manager = autofree(GameStateManager.new())
	assert_eq(_damage(await _respond("spark_gap")), [] as Array[int])


func test_napalm_vent_burns_only_in_a_fight() -> void:
	var burns: Array[EffectEvent] = (await _respond("napalm_vent")).filter(
		func(e: EffectEvent) -> bool: return e is ApplyStatusEvent)
	assert_eq(burns.size(), 1)
	# A fresh manager starts out of combat.
	Globals.state_manager = autofree(GameStateManager.new())
	burns = (await _respond("napalm_vent")).filter(
		func(e: EffectEvent) -> bool: return e is ApplyStatusEvent)
	assert_eq(burns.size(), 0)
