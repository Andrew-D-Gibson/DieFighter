extends "res://test/helpers/die_fighter_test.gd"
## The wave-fight answers: Sweeping Battery hits every enemy and gives its die
## to the target alone.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const TILES: String = "res://Source/Content/Tiles/TileResources/%s.tres"

var engine: RecordingEngine
var targeted: Enemy
var other: Enemy
var tile: Tile


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	targeted = _enemy()
	other = _enemy()
	var computer: TargetingComputer = autofree(TargetingComputer.new())
	computer.targeted_enemy = targeted
	Globals.targeting_computer = computer
	var roster: EnemyManager = autofree(EnemyManager.new())
	roster.enemies = [targeted, other] as Array[Enemy]
	Globals.enemy_manager = roster
	Globals.player = make_player()
	tile = autofree(TILE_SCENE.instantiate())
	tile.sprite_frames = null


func after_each() -> void:
	Globals.enemy_manager = null
	super()


func _enemy() -> Enemy:
	var enemy: Enemy = autofree(ENEMY_SCENE.instantiate())
	enemy.health.max_health = 20
	enemy.health.health = 20
	enemy.scenario_state = ScenarioShipState.new()
	return enemy


func _play(tile_id: String, face: int) -> Array[EffectEvent]:
	var resource: TileResource = load(TILES % tile_id)
	tile.tile_resource = resource
	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = face
	var context := EffectContext.new()
	context.effect_source = tile
	context.activator_die = die
	await resource.effect_chain.play(context, engine)
	return engine.injected.duplicate()


func _turn_start(tile_id: String) -> Array[EffectEvent]:
	var resource: TileResource = load(TILES % tile_id)
	tile.tile_resource = resource
	var chain: EffectChain = null
	for trigger: TileEvent in resource.event_responses:
		if trigger.event == TileEvent.EventType.ON_TURN_START:
			chain = resource.event_responses[trigger]
	assert_not_null(chain, "answers the turn starting")
	var context := EffectContext.new()
	context.effect_source = tile
	await chain.play(context, engine)
	return engine.injected.duplicate()


func _of(events: Array[EffectEvent], script: Script) -> Array[EffectEvent]:
	return events.filter(func(e: EffectEvent) -> bool: return is_instance_of(e, script))


func test_sweeping_battery_takes_a_five_or_a_six() -> void:
	tile.tile_resource = load(TILES % "sweeping_battery")
	var die: Dice = autofree(DICE_SCENE.instantiate())
	for face: int in [1, 2, 3, 4]:
		die.value = face
		assert_ne(tile.activation_refusal(die), "", "refuses a %d" % face)
	for face: int in [5, 6]:
		die.value = face
		assert_eq(tile.activation_refusal(die), "", "takes a %d" % face)


func test_sweeping_battery_hits_every_enemy_and_gives_the_target_its_die() -> void:
	var events: Array[EffectEvent] = await _play("sweeping_battery", 5)
	var hits: Array[EffectEvent] = _of(events, DamageEvent)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].amount, 4)
	assert_eq(hits[0].targets, [targeted, other] as Array[Node])
	var gives: Array[EffectEvent] = _of(events, GiveDieToTargetEvent)
	assert_eq(gives.size(), 1)
	assert_eq(gives[0].targets, [targeted] as Array[Node], "only the ship that keeps the die sees it thrown")


func test_sweeping_battery_plus_hits_for_six() -> void:
	var hits: Array[EffectEvent] = _of(await _play("sweeping_battery_plus", 6), DamageEvent)
	assert_eq(hits[0].amount, 6)

