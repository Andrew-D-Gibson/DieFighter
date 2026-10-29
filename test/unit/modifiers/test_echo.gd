extends "res://test/helpers/die_fighter_test.gd"
## Echo (EchoModifier): the next tile activation plays its whole chain twice
## and hands its die on once. Echoes queue, wait out activations that can't
## use them, and lapse when the turn or the fight ends.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const DAMAGE_TILE: TileResource = preload("res://Source/Content/Tiles/TileResources/damage.tres")
const REROLL_TILE: TileResource = preload("res://Source/Content/Tiles/TileResources/reroll.tres")
const FORTRESS: TileResource = preload("res://Source/Content/Tiles/TileResources/fortress_protocol.tres")
const DEAD_SYSTEMS: String = "res://Source/Resources/BackgroundResources/BackgroundModifiers/dead_systems.tres"

var engine: ScenarioEngine
var cannon: Tile
var source: Tile
var enemy: Enemy


func before_each() -> void:
	super()
	engine = autofree(ScenarioEngine.new())
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = engine
	Globals.scenario_manager = manager
	cannon = _tile(DAMAGE_TILE)
	source = _tile(REROLL_TILE)
	var grid: TileGrid = autofree(TileGrid.new())
	grid.tile_locations[Vector2i(0, 0)] = source
	grid.tile_locations[Vector2i(1, 0)] = cannon
	Globals.tile_grid = grid
	# The Dice Cannon takes a die only while a ship is targeted.
	enemy = autofree(ENEMY_SCENE.instantiate())
	enemy.scenario_state = ScenarioShipState.new()
	var computer: TargetingComputer = autofree(TargetingComputer.new())
	computer.targeted_enemy = enemy
	Globals.targeting_computer = computer


func _tile(resource: TileResource) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.tile_resource = resource
	return tile


func _die(face: int = 3) -> Dice:
	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = face
	return die


func _activation(tile: Tile, face: int = 3) -> TileActivationEvent:
	var event := TileActivationEvent.new()
	event.tile = tile
	event.activator_die = _die(face)
	event.die_value = face
	return event


## Runs every modifier's before-hook on [param event], as the engine does.
func _before(event: TileActivationEvent) -> void:
	for mod: Modifier in engine.modifiers.duplicate():
		if mod in engine.modifiers and not event.canceled:
			await mod.on_before_event(event, engine)


func _arm() -> void:
	var arm := ArmEchoEvent.new()
	arm.effect_source = source
	await arm.resolve(engine)


func test_arming_puts_an_echo_in_play_on_its_tile() -> void:
	await _arm()
	assert_eq(EchoModifier.armed_count(engine), 1)
	var echo: EchoModifier = engine.modifiers[0] as EchoModifier
	assert_eq(echo.source, source)
	assert_eq(echo.affected_node, source, "the visual shows on the tile that armed it")
	assert_string_contains(echo.get_info_text(), "Echo armed")


func test_the_next_activation_runs_twice_and_spends_the_echo() -> void:
	await _arm()
	var event: TileActivationEvent = _activation(cannon)
	await _before(event)
	assert_eq(event.activation_repetitions, 2)
	assert_true(event.echoed)
	assert_eq(EchoModifier.armed_count(engine), 0)


func test_two_echoes_double_two_tiles_rather_than_one_tile_twice() -> void:
	await _arm()
	await _arm()
	var first: TileActivationEvent = _activation(cannon)
	await _before(first)
	assert_eq(first.activation_repetitions, 2, "x2, not x4")
	assert_eq(EchoModifier.armed_count(engine), 1)
	var second: TileActivationEvent = _activation(cannon)
	await _before(second)
	assert_eq(second.activation_repetitions, 2)
	assert_eq(EchoModifier.armed_count(engine), 0)


func test_a_refused_die_leaves_the_echo_waiting() -> void:
	await _arm()
	var spent: Tile = _tile(REROLL_TILE)
	spent.uses_remaining = 0
	var event: TileActivationEvent = _activation(spent)
	await _before(event)
	assert_eq(event.activation_repetitions, 1)
	assert_eq(EchoModifier.armed_count(engine), 1)


func test_a_tile_that_ignores_echo_is_skipped() -> void:
	var fortress: Tile = _tile(FORTRESS)
	assert_false(FORTRESS.can_be_echoed)
	await _arm()
	var event: TileActivationEvent = _activation(fortress, 6)
	await _before(event)
	assert_eq(event.activation_repetitions, 1, "doubling shields twice would be x4")
	assert_eq(EchoModifier.armed_count(engine), 1)
	assert_string_contains(engine.modifiers[0].get_rule_info_text(fortress), "skips")
	assert_eq(engine.modifiers[0].get_rule_info_text(cannon), "")


func test_a_rule_holding_tiles_to_one_pass_leaves_the_echo_waiting() -> void:
	engine.add_modifier((load(DEAD_SYSTEMS) as BackgroundModifierResource).create_modifier())
	await _arm()
	var event: TileActivationEvent = _activation(cannon)
	await _before(event)
	assert_eq(event.activation_repetitions, 1)
	assert_eq(EchoModifier.armed_count(engine), 1)


func test_an_unspent_echo_lapses_when_the_turn_ends() -> void:
	await _arm()
	Events.player_turn_over.emit()
	assert_eq(EchoModifier.armed_count(engine), 0)


func test_an_unspent_echo_never_reaches_the_next_fight() -> void:
	await _arm()
	Events.combat_finished.emit()
	assert_eq(EchoModifier.armed_count(engine), 0)


func test_a_spent_echo_stops_listening_for_the_turn_end() -> void:
	await _arm()
	var echo: EchoModifier = engine.modifiers[0] as EchoModifier
	await _before(_activation(cannon))
	assert_false(Events.player_turn_over.is_connected(echo._lapse))


## Whole chain: the echoed Dice Cannon hits twice and gives its die once.
func test_an_echoed_cannon_hits_twice_and_gives_its_die_once() -> void:
	var recorder: RecordingEngine = autofree(RecordingEngine.new())
	Globals.player = make_player()

	await _arm()
	var event: TileActivationEvent = _activation(cannon, 4)
	await _before(event)
	var context := EffectContext.new()
	context.effect_source = cannon
	context.activator_die = event.activator_die
	context.repetitions = event.activation_repetitions
	await DAMAGE_TILE.effect_chain.play(context, recorder)
	var hits: Array[EffectEvent] = recorder.injected_of(DamageEvent)
	assert_eq(hits.size(), 2)
	for hit: EffectEvent in hits:
		assert_eq(hit.amount, 4)
	assert_eq(recorder.injected_of(GiveDieToTargetEvent).size(), 1)


func test_the_arm_step_arms_once_per_pass() -> void:
	var recorder: RecordingEngine = autofree(RecordingEngine.new())
	var effects: Array[EffectData] = [
		Effects.data(EffectEnums.Category.TILE_CONTROL, EffectEnums.TileControlSubtype.ARM_ECHO),
	]
	var context := EffectContext.new()
	context.effect_source = source
	context.repetitions = 2
	await Effects.chain(effects).play(context, recorder)
	assert_eq(recorder.injected_of(ArmEchoEvent).size(), 2)
	assert_eq(recorder.injected[0].effect_source, source)


## Plays [param resource]'s chain from the source cell (0, 0), with the Dice
## Cannon to its right, [param passes] times over, and returns what it made.
func _play_from_source(resource: TileResource, passes: int = 1) -> Array[EffectEvent]:
	var recorder: RecordingEngine = autofree(RecordingEngine.new())
	Globals.tile_grid.set_cells([Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i])
	Globals.player = make_player()
	source.tile_resource = resource
	var context := EffectContext.new()
	context.effect_source = source
	context.activator_die = _die(2)
	context.repetitions = passes
	await resource.effect_chain.play(context, recorder)
	return recorder.injected.duplicate()


func _of(events: Array[EffectEvent], script: Script) -> Array[EffectEvent]:
	return events.filter(func(e: EffectEvent) -> bool: return is_instance_of(e, script))


func test_echo_relay_arms_before_it_feeds_right() -> void:
	var events: Array[EffectEvent] = await _play_from_source(load("res://Source/Content/Tiles/TileResources/echo_relay.tres"))
	var arm: Array[EffectEvent] = _of(events, ArmEchoEvent)
	var feed: Array[EffectEvent] = _of(events, PassDieToTileEvent)
	assert_eq(arm.size(), 1)
	assert_eq(feed.size(), 1)
	assert_lt(events.find(arm[0]), events.find(feed[0]), "the fed tile is the one it echoes")
	assert_eq(feed[0].targets, [cannon] as Array[Node])


func test_an_echoed_echo_relay_arms_two_and_feeds_once() -> void:
	var events: Array[EffectEvent] = await _play_from_source(load("res://Source/Content/Tiles/TileResources/echo_relay.tres"), 2)
	assert_eq(_of(events, ArmEchoEvent).size(), 2)
	assert_eq(_of(events, PassDieToTileEvent).size(), 1)


func test_echo_relay_plus_has_a_second_use() -> void:
	var base: TileResource = load("res://Source/Content/Tiles/TileResources/echo_relay.tres")
	assert_eq(base.uses_per_turn, 1)
	assert_eq(base.upgraded_version.uses_per_turn, 2, "relays stay at 1-2 uses")



## Plays [param resource]'s turn-start response from the source tile.
func _turn_start(resource: TileResource) -> Array[EffectEvent]:
	var recorder: RecordingEngine = autofree(RecordingEngine.new())
	source.tile_resource = resource
	var chain: EffectChain = null
	for trigger: TileEvent in resource.event_responses:
		if trigger.event == TileEvent.EventType.ON_TURN_START:
			chain = resource.event_responses[trigger]
	assert_not_null(chain, "answers the turn starting")
	var context := EffectContext.new()
	context.effect_source = source
	await chain.play(context, recorder)
	return recorder.injected.duplicate()


func test_opening_salvo_arms_an_echo_as_the_turn_starts() -> void:
	var salvo: TileResource = load("res://Source/Content/Tiles/TileResources/opening_salvo.tres")
	var arms: Array[EffectEvent] = _of(await _turn_start(salvo), ArmEchoEvent)
	assert_eq(arms.size(), 1)
	assert_eq(arms[0].effect_source, source)
	assert_eq(_of(await _turn_start(salvo.upgraded_version), ArmEchoEvent).size(), 2,
		"the upgrade echoes the first two tiles")


func test_opening_salvo_takes_no_dice() -> void:
	source.tile_resource = load("res://Source/Content/Tiles/TileResources/opening_salvo.tres")
	assert_ne(source.activation_refusal(_die()), "")


## The turn-start sweep of temporary modifiers runs on the same beat Opening
## Salvo arms its echo, so the echo must not be one of them.
func test_an_echo_armed_at_turn_start_survives_the_turn_start_sweep() -> void:
	await _arm()
	engine.clear_temporary_modifiers()
	assert_eq(EchoModifier.armed_count(engine), 1)
