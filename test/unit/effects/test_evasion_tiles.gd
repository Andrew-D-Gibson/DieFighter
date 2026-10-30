extends "res://test/helpers/die_fighter_test.gd"
## The tiles built on the engines' evasion: Juke Thrusters raises it for a
## round, and Afterimage, Slipstream Vane and Feint Cannon pay out on a miss.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const TILES: String = "res://Source/Content/Tiles/TileResources/%s.tres"

## Records the chains tiles play.
var recorder: RecordingEngine
## Resolves events for real, and holds the evasion rule.
var engine: ScenarioEngine
var evasion: EvasionModifier
var player: Player
var enemy: Enemy


func before_each() -> void:
	super()
	recorder = autofree(RecordingEngine.new())
	engine = add_child_autofree(ScenarioEngine.new())
	evasion = EvasionModifier.new()
	engine.add_modifier(evasion)
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = engine
	Globals.scenario_manager = manager
	var state: GameStateManager = autofree(GameStateManager.new())
	state.state = GameStateManager.GameState.IN_COMBAT
	Globals.state_manager = state
	player = add_child_autofree(PLAYER_SCENE.instantiate())
	player.num_of_dice = 3
	player.engine_charge = 0
	Globals.player = player
	enemy = autofree(ENEMY_SCENE.instantiate())
	enemy.scenario_state = ScenarioShipState.new()
	enemy.scenario_state.attitude = Enemy.Attitude.AGGRESSIVE
	var computer: TargetingComputer = autofree(TargetingComputer.new())
	computer.targeted_enemy = enemy
	Globals.targeting_computer = computer
	var roster: EnemyManager = autofree(EnemyManager.new())
	roster.enemies = [enemy] as Array[Enemy]
	Globals.enemy_manager = roster
	Globals.tile_grid = autofree(TileGrid.new())


func _tile(tile_id: String) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.sprite_frames = null
	tile.tile_resource = load(TILES % tile_id)
	return tile


func _die(face: int) -> Dice:
	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = face
	return die


func _takes(tile_id: String, face: int) -> bool:
	return _tile(tile_id).activation_refusal(_die(face)).is_empty()


## Plays [param tile]'s chain with a die of [param face] into the recorder
## and returns what it produced.
func _play_tile(tile: Tile, face: int) -> Array[EffectEvent]:
	recorder.injected.clear()
	Globals.tile_grid.tile_locations[Vector2i(1, 1)] = tile
	var context: EffectContext = EffectContext.new()
	context.actor = player
	context.effect_source = tile
	context.activator_die = _die(face)
	await tile.tile_resource.effect_chain.play(context, recorder)
	return recorder.injected.duplicate()


func _of(events: Array[EffectEvent], script: Script) -> Array[EffectEvent]:
	return events.filter(func(e: EffectEvent) -> bool: return is_instance_of(e, script))


## [param tile_id] on the grid and listening, with the engine swapped for
## the recorder so its responses can be read back.
func _listening(tile_id: String) -> Tile:
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = load(TILES % tile_id)
	add_child_autofree(tile)
	Globals.tile_grid.tile_locations[Vector2i(0, 0)] = tile
	Globals.scenario_manager.engine = recorder
	recorder.injected.clear()
	return tile


## Plays every tile response the recorder caught, and returns what they did.
func _responses() -> Array[EffectEvent]:
	var triggered: Array[EffectEvent] = _of(recorder.injected, TileEventTriggeredEvent)
	recorder.injected.clear()
	for event: EffectEvent in triggered:
		await event.resolve(recorder)
	return recorder.injected.duplicate()


# ── Juke Thrusters ────────────────────────────────────────────────────────────

func test_juke_thrusters_adds_four_percent_a_pip_and_hands_the_target_the_die() -> void:
	var events: Array[EffectEvent] = await _play_tile(_tile("juke_thrusters"), 5)
	var adds: Array[EffectEvent] = _of(events, AddEvasionEvent)
	assert_eq(adds.size(), 1)
	assert_eq(adds[0].amount, 20)
	var gives: Array[EffectEvent] = _of(events, GiveDieToTargetEvent)
	assert_eq(gives.size(), 1)
	assert_eq(gives[0].targets, [enemy] as Array[Node], "the core trade: the die goes to the target")


func test_juke_thrusters_plus_adds_six_percent_a_pip() -> void:
	var events: Array[EffectEvent] = await _play_tile(_tile("juke_thrusters_plus"), 5)
	assert_eq(_of(events, AddEvasionEvent)[0].amount, 30)


func test_the_boost_lands_on_the_evasion_rule_until_the_enemy_turn_ends() -> void:
	var boost: AddEvasionEvent = AddEvasionEvent.new()
	boost.amount = 24
	await boost.resolve(engine)
	assert_eq(evasion.chance_percent(), 24)
	player.engine_charge = 10
	assert_eq(evasion.chance_percent(), 50, "the drive's 30% on top, held to the cap")
	Events.enemy_turn_over.emit()
	assert_eq(evasion.chance_percent(), 30)


func test_an_amplifier_does_not_grow_the_boost() -> void:
	assert_false(AddEvasionEvent.new().is_amplifiable())


func test_juke_thrusters_refuses_a_die_it_would_waste() -> void:
	assert_true(_takes("juke_thrusters", 3))
	player.num_of_dice = 6
	player.engine_charge = player.max_engine_charge
	assert_eq(evasion.chance_percent(), EvasionModifier.MAX_PERCENT)
	assert_false(_takes("juke_thrusters", 3), "already at the cap")
	player.engine_charge = 0
	Globals.state_manager.state = GameStateManager.GameState.OUT_OF_COMBAT
	assert_false(_takes("juke_thrusters", 3), "nothing to dodge outside a fight")
	Globals.state_manager.state = GameStateManager.GameState.IN_COMBAT
	Globals.targeting_computer.targeted_enemy = null
	assert_false(_takes("juke_thrusters", 3), "needs a ship to give the die to")


# ── Afterimage and Slipstream Vane ───────────────────────────────────────────

func test_afterimage_shields_you_when_a_hit_misses() -> void:
	_listening("afterimage")
	Events.player_evaded.emit(enemy)
	var shields: Array[EffectEvent] = _of(await _responses(), ShieldEvent)
	assert_eq(shields.size(), 1)
	assert_eq(shields[0].amount, 4)
	assert_eq(shields[0].targets, [player] as Array[Node])


func test_afterimage_plus_gives_six() -> void:
	_listening("afterimage_plus")
	Events.player_evaded.emit(enemy)
	assert_eq(_of(await _responses(), ShieldEvent)[0].amount, 6)


func test_afterimage_ignores_a_hit_that_lands() -> void:
	_listening("afterimage")
	Events.player_attacked.emit(enemy)
	assert_eq(_of(recorder.injected, TileEventTriggeredEvent).size(), 0)


func test_slipstream_vane_charges_the_engine_when_a_hit_misses() -> void:
	_listening("slipstream_vane")
	Events.player_evaded.emit(enemy)
	var charges: Array[EffectEvent] = _of(await _responses(), ChangeEngineChargeEvent)
	assert_eq(charges.size(), 1)
	assert_eq(charges[0].amount, 2)


func test_slipstream_vane_plus_charges_three() -> void:
	_listening("slipstream_vane_plus")
	Events.player_evaded.emit(enemy)
	assert_eq(_of(await _responses(), ChangeEngineChargeEvent)[0].amount, 3)


func test_the_passives_take_no_dice() -> void:
	for tile_id: String in ["afterimage", "slipstream_vane"]:
		for face: int in range(1, 7):
			assert_false(_takes(tile_id, face), "%s turns away a %d" % [tile_id, face])


# ── Feint Cannon ─────────────────────────────────────────────────────────────

func test_feint_cannon_takes_only_ones_and_twos() -> void:
	assert_true(_takes("feint_cannon", 1))
	assert_true(_takes("feint_cannon", 2))
	for face: int in range(3, 7):
		assert_false(_takes("feint_cannon", face), "turns away a %d" % face)


func test_feint_cannon_hits_for_two_plus_its_banked_misses() -> void:
	var tile: Tile = _tile("feint_cannon")
	var events: Array[EffectEvent] = await _play_tile(tile, 1)
	var hits: Array[EffectEvent] = _of(events, DamageEvent)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].amount, 2, "nothing banked yet")
	assert_eq(hits[0].targets, [enemy] as Array[Node])
	tile.effect_data["feint"] = 6
	hits = _of(await _play_tile(tile, 2), DamageEvent)
	assert_eq(hits[0].amount, 8, "two misses banked")


func test_feint_cannon_banks_three_a_miss_on_itself() -> void:
	var tile: Tile = _listening("feint_cannon")
	Events.player_evaded.emit(enemy)
	var banks: Array[EffectEvent] = _of(await _responses(), IncrementTileDataEvent)
	assert_eq(banks.size(), 1)
	assert_eq(banks[0].amount, 3)
	assert_eq((banks[0] as IncrementTileDataEvent).data_key, "feint")
	assert_eq(banks[0].effect_source, tile)


func test_feint_cannon_plus_banks_four() -> void:
	_listening("feint_cannon_plus")
	Events.player_evaded.emit(enemy)
	assert_eq(_of(await _responses(), IncrementTileDataEvent)[0].amount, 4)


func test_feint_cannon_starts_every_fight_empty() -> void:
	var tile: Tile = _listening("feint_cannon")
	tile.effect_data["feint"] = 9
	Events.first_turn_start.emit()
	var resets: Array[EffectEvent] = []
	for event: EffectEvent in await _responses():
		if event.get("data_key") == "feint":
			resets.append(event)
	assert_eq(resets.size(), 1)
	assert_eq(resets[0].amount, 0)


# ── Upgrades ─────────────────────────────────────────────────────────────────

func test_every_evasion_tile_upgrades() -> void:
	for tile_id: String in ["juke_thrusters", "afterimage", "slipstream_vane", "feint_cannon"]:
		var base: TileResource = load(TILES % tile_id)
		assert_true(base.offered_as_reward, tile_id)
		assert_eq(base.upgraded_version, load(TILES % (tile_id + "_plus")), tile_id)
		assert_true(base.upgraded_version.is_upgrade)
