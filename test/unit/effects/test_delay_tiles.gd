extends "res://test/helpers/die_fighter_test.gd"
## The tiles that act on a later turn play their chains whole: Time Bomb plants
## a bomb that goes off two turns later, and Holding Bay keeps a die for the
## next turn. Also what the AutoPilot's forecast makes of them.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const Ships := preload("res://test/helpers/ships.gd")
const TILES: String = "res://Source/Content/Tiles/TileResources/%s.tres"

var engine: RecordingEngine
var enemy: Enemy
var state: GameStateManager


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = engine
	Globals.scenario_manager = manager
	enemy = autofree(ENEMY_SCENE.instantiate())
	enemy.health.max_health = 60
	enemy.health.health = 60
	enemy.scenario_state = ScenarioShipState.new()
	enemy.scenario_state.attitude = Enemy.Attitude.AGGRESSIVE
	var computer: TargetingComputer = autofree(TargetingComputer.new())
	computer.targeted_enemy = enemy
	Globals.targeting_computer = computer
	var roster: EnemyManager = autofree(EnemyManager.new())
	roster.enemies = [enemy] as Array[Enemy]
	Globals.enemy_manager = roster
	state = autofree(GameStateManager.new())
	Globals.state_manager = state
	state.state = GameStateManager.GameState.IN_COMBAT
	Globals.player = make_player(3)


func after_each() -> void:
	engine.clear_modifiers()
	super()


func _tile(tile_id: String) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.tile_resource = load(TILES % tile_id)
	return tile


func _die(face: int) -> Dice:
	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = face
	return die


func _play(tile: Tile, face: int) -> Array[EffectEvent]:
	engine.injected.clear()
	var context: EffectContext = EffectContext.new()
	context.actor = Globals.player
	context.effect_source = tile
	context.activator_die = _die(face)
	await tile.tile_resource.effect_chain.play(context, engine)
	return engine.injected.duplicate()


func _of(events: Array[EffectEvent], script: Script) -> Array[EffectEvent]:
	return events.filter(func(e: EffectEvent) -> bool: return is_instance_of(e, script))


# ── Time Bomb ─────────────────────────────────────────────────────────────────

func test_time_bomb_takes_only_fives_and_sixes_in_a_fight_with_a_target() -> void:
	var tile: Tile = _tile("time_bomb")
	assert_eq(tile.activation_refusal(_die(5)), "")
	assert_eq(tile.activation_refusal(_die(6)), "")
	assert_ne(tile.activation_refusal(_die(4)), "")
	state.state = GameStateManager.GameState.OUT_OF_COMBAT
	assert_ne(tile.activation_refusal(_die(6)), "", "no later turn to go off on")


func test_time_bomb_arms_four_times_the_die_on_the_target_and_gives_it_the_die() -> void:
	var events: Array[EffectEvent] = await _play(_tile("time_bomb"), 6)
	var armed: Array[EffectEvent] = _of(events, ArmDelayedPayloadEvent)
	assert_eq(armed.size(), 1)
	assert_eq(armed[0].amount, 24)
	assert_eq(armed[0].targets, [enemy] as Array[Node])
	assert_eq((armed[0] as ArmDelayedPayloadEvent).payload.amount, 2, "two turns")
	assert_eq(_of(events, DamageEvent).size(), 0, "nothing lands now")
	var given: Array[EffectEvent] = _of(events, GiveDieToTargetEvent)
	assert_eq(given.size(), 1)


func test_time_bomb_plus_arms_five_times_the_die() -> void:
	var events: Array[EffectEvent] = await _play(_tile("time_bomb_plus"), 5)
	assert_eq(_of(events, ArmDelayedPayloadEvent)[0].amount, 25)


func test_the_bomb_goes_off_on_the_second_turn_start_for_the_armed_damage() -> void:
	var tile: Tile = _tile("time_bomb")
	var events: Array[EffectEvent] = await _play(tile, 5)
	await _of(events, ArmDelayedPayloadEvent)[0].resolve(engine)
	engine.injected.clear()

	Events.player_turn_refresh.emit()
	assert_eq(engine.injected_of(DelayedPayloadEvent).size(), 0, "one turn to go")
	Events.player_turn_refresh.emit()
	var fired: Array[EffectEvent] = engine.injected_of(DelayedPayloadEvent)
	assert_eq(fired.size(), 1)
	assert_eq(fired[0].effect_source, tile, "the tile's hit, for modifiers on it then")

	engine.injected.clear()
	await fired[0].resolve(engine)
	var hits: Array[EffectEvent] = engine.injected_of(DamageEvent)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].amount, 20)
	assert_eq(hits[0].targets, [enemy] as Array[Node])


func test_the_forecast_values_a_bomb_below_the_same_hit_now() -> void:
	var tile: Tile = _tile("time_bomb")
	var forecast: AutoPilotForecast = AutoPilotForecast.of(tile, autofree(FakeDie.new(6)), enemy,
			Ships.roster([enemy]))
	var expected: float = 24.0 * 0.6 * 0.6
	assert_almost_eq(forecast.damage.get(enemy, 0.0), expected, 0.01)
	assert_eq(forecast.handoffs.size(), 1, "the die still goes to the target")


# ── Holding Bay ───────────────────────────────────────────────────────────────

func test_holding_bay_holds_the_die_for_one_turn_and_gives_nothing_away() -> void:
	var events: Array[EffectEvent] = await _play(_tile("holding_bay"), 4)
	var held: Array[EffectEvent] = _of(events, HoldDieForTurnsEvent)
	assert_eq(held.size(), 1)
	assert_eq(held[0].amount, 1)
	assert_eq(_of(events, GiveDieToTargetEvent).size(), 0)


func test_holding_bay_works_only_in_a_fight() -> void:
	var tile: Tile = _tile("holding_bay")
	assert_eq(tile.activation_refusal(_die(1)), "")
	state.state = GameStateManager.GameState.OUT_OF_COMBAT
	assert_ne(tile.activation_refusal(_die(1)), "", "out of a fight there's no next turn")


func test_holding_bay_has_one_use_and_its_upgrade_two() -> void:
	assert_eq((load(TILES % "holding_bay") as TileResource).uses_per_turn, 1)
	assert_eq((load(TILES % "holding_bay_plus") as TileResource).uses_per_turn, 2)


func test_the_forecast_keeps_a_held_die_from_the_ships() -> void:
	var forecast: AutoPilotForecast = AutoPilotForecast.of(_tile("holding_bay"),
			autofree(FakeDie.new(6)), enemy, Ships.roster([enemy]))
	assert_eq(forecast.handoffs.size(), 0)
	assert_eq(forecast.dice_back, 0.0, "not back this turn")
	assert_gt(forecast.tile_tricks, 0.0)
