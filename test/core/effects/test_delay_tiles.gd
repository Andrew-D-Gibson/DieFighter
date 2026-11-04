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
