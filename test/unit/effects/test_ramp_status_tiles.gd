extends "res://test/helpers/die_fighter_test.gd"
## The ramp family and the status payoffs: Ratchet Cannon grows for the whole
## fight, War Footing builds a fight-long damage boost for every red tile,
## Status Catalyst doubles every status on its target, and Hex Coil hits a
## ship each time the player puts a status on it.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const TILES: String = "res://Source/Content/Tiles/TileResources/%s.tres"

var engine: RecordingEngine
var targeted: Enemy
var other: Enemy


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = engine
	Globals.scenario_manager = manager
	targeted = _enemy()
	other = _enemy()
	var computer: TargetingComputer = autofree(TargetingComputer.new())
	computer.targeted_enemy = targeted
	Globals.targeting_computer = computer
	var roster: EnemyManager = autofree(EnemyManager.new())
	roster.enemies = [targeted, other] as Array[Enemy]
	Globals.enemy_manager = roster
	# The real ship: statuses put on the player need its hull and status bar.
	Globals.player = add_child_autofree(PLAYER_SCENE.instantiate())


func after_each() -> void:
	Globals.enemy_manager = null
	super()


func _enemy() -> Enemy:
	var enemy: Enemy = autofree(ENEMY_SCENE.instantiate())
	enemy.health.max_health = 30
	enemy.health.health = 30
	enemy.scenario_state = ScenarioShipState.new()
	return enemy


## A tile outside the tree. Its sprite is dropped so setting the resource
## doesn't start a tween that needs the tree.
func _tile(tile_id: String) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.sprite_frames = null
	tile.tile_resource = load(TILES % tile_id)
	return tile


## A tile in the tree, so it listens to the game's events as it does on the
## grid.
func _listening_tile(tile_id: String) -> Tile:
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = load(TILES % tile_id)
	add_child_autofree(tile)
	return tile


func _die(face: int) -> Dice:
	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = face
	return die


func _play(tile: Tile, face: int) -> Array[EffectEvent]:
	engine.injected.clear()
	var context := EffectContext.new()
	context.actor = Globals.player
	context.effect_source = tile
	context.activator_die = _die(face)
	await tile.tile_resource.effect_chain.play(context, engine)
	return engine.injected.duplicate()


func _response(tile: Tile, event: TileEvent.EventType) -> EffectChain:
	for trigger: TileEvent in tile.tile_resource.event_responses:
		if trigger.event == event:
			return tile.tile_resource.event_responses[trigger]
	return null


func _respond(tile: Tile, event: TileEvent.EventType) -> Array[EffectEvent]:
	engine.injected.clear()
	var chain: EffectChain = _response(tile, event)
	assert_not_null(chain, "answers %s" % TileEvent.EventType.find_key(event))
	var context := EffectContext.new()
	context.actor = Globals.player
	context.effect_source = tile
	await chain.play(context, engine)
	return engine.injected.duplicate()


func _of(events: Array[EffectEvent], script: Script) -> Array[EffectEvent]:
	return events.filter(func(e: EffectEvent) -> bool: return is_instance_of(e, script))


## Resolves every captured event of [param script], in order.
func _resolve(events: Array[EffectEvent], script: Script) -> void:
	for event: EffectEvent in _of(events, script):
		await event.resolve(engine)


func _apply(target: Node, status_id: StringName, stacks: int, actor: Node = null) -> void:
	var event := ApplyStatusEvent.new()
	event.actor = actor if actor else Globals.player
	event.status_id = status_id
	event.amount = stacks
	event.targets = [target] as Array[Node]
	await event.resolve(engine)


func _stacks(ship: Node, status_id: StringName) -> int:
	var status: StatusModifier = engine.find_status(ship, status_id)
	return status.stacks if status else 0


# ── Spotter Drone ─────────────────────────────────────────────────────────────

func test_spotter_drone_exposes_the_target_and_you() -> void:
	for tile_id: String in ["spotter_drone", "spotter_drone_plus"]:
		var drone: Tile = _tile(tile_id)
		var applied: Array[EffectEvent] = _of(
			await _respond(drone, TileEvent.EventType.ON_ENEMY_TURN_OVER), ApplyStatusEvent
		)
		assert_eq(applied.size(), 2, tile_id)
		if applied.size() != 2:
			continue
		assert_eq(applied[0].amount, 3 if tile_id == "spotter_drone" else 5, tile_id)
		assert_true(targeted in applied[0].targets, "the target is exposed")
		assert_eq(applied[1].amount, 2, "%s costs the same" % tile_id)
		assert_eq(applied[1].targets, [Globals.player] as Array[Node], "and so are you")


# ── Ratchet Cannon ────────────────────────────────────────────────────────────

func test_ratchet_cannon_takes_only_a_four() -> void:
	var tile: Tile = _tile("ratchet_cannon")
	for face: int in [1, 2, 3, 5, 6]:
		assert_ne(tile.activation_refusal(_die(face)), "", "refuses a %d" % face)
	assert_eq(tile.activation_refusal(_die(4)), "")


func test_ratchet_cannon_grows_by_two_a_use_and_keeps_it() -> void:
	var tile: Tile = _tile("ratchet_cannon")
	var damages: Array[int] = []
	for i: int in 3:
		var events: Array[EffectEvent] = await _play(tile, 4)
		damages.append(_of(events, DamageEvent)[0].amount)
		assert_eq(_of(events, GiveDieToTargetEvent).size(), 1, "the die goes to the target")
		await _resolve(events, IncrementTileDataEvent)
	assert_eq(damages, [3, 5, 7] as Array[int])
	assert_eq(tile.effect_data.get("ratchet", 0), 6)
	# A new turn doesn't reset it, unlike Overclock Coil.
	assert_null(_response(tile, TileEvent.EventType.ON_TURN_START))


func test_ratchet_cannon_resets_when_a_fight_starts() -> void:
	var tile: Tile = _tile("ratchet_cannon")
	tile.effect_data["ratchet"] = 8
	await _resolve(await _respond(tile, TileEvent.EventType.ON_COMBAT_START), SetTileDataEvent)
	assert_eq(tile.effect_data["ratchet"], 0)


func test_ratchet_cannon_shows_its_bonus() -> void:
	var tile: Tile = _tile("ratchet_cannon")
	tile.effect_data["ratchet"] = 6
	assert_string_contains(Tile.fill_data_tokens(tile.tile_resource.description, tile.effect_data), "(+6)")


func test_ratchet_cannon_plus_grows_by_three() -> void:
	var tile: Tile = _tile("ratchet_cannon_plus")
	await _resolve(await _play(tile, 4), IncrementTileDataEvent)
	assert_eq(_of(await _play(tile, 4), DamageEvent)[0].amount, 6)


func test_a_fights_reset_is_queued_ahead_of_its_first_turn() -> void:
	var resource := TileResource.new()
	resource.uses_per_turn = -1
	resource.textures = load(TILES % "ratchet_cannon").textures
	var on_start := TileEvent.new()
	on_start.event = TileEvent.EventType.ON_COMBAT_START
	var on_turn := TileEvent.new()
	on_turn.event = TileEvent.EventType.ON_TURN_START
	var start_chain := EffectChain.new()
	var turn_chain := EffectChain.new()
	# The turn's listener goes in first, so the order isn't the dictionary's.
	resource.event_responses[on_turn] = turn_chain
	resource.event_responses[on_start] = start_chain
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = resource
	add_child_autofree(tile)

	Events.first_turn_start.emit()
	var answers: Array[EffectEvent] = engine.injected_of(TileEventTriggeredEvent)
	assert_eq(answers.size(), 2)
	assert_eq((answers[0] as TileEventTriggeredEvent).chain, start_chain)
	assert_eq((answers[1] as TileEventTriggeredEvent).chain, turn_chain)

	# A later turn is not a new fight.
	engine.injected.clear()
	Events.player_turn_start.emit()
	answers = engine.injected_of(TileEventTriggeredEvent)
	assert_eq(answers.size(), 1)
	assert_eq((answers[0] as TileEventTriggeredEvent).chain, turn_chain)


# ── War Footing ───────────────────────────────────────────────────────────────

func _boost(owner: Tile) -> FamilyBoostModifier:
	return FamilyBoostModifier.find(engine, owner, ColorSymbolBadge.Family.RED)


func _hit_from(tile: Tile, amount: int = 3, actor: Node = null) -> DamageEvent:
	var hit := DamageEvent.new()
	hit.actor = actor if actor else Globals.player
	hit.effect_source = tile
	hit.amount = amount
	hit.targets = [targeted] as Array[Node]
	for mod: Modifier in engine.modifiers:
		mod.on_before_event(hit, engine)
	return hit


func _turn_starts(footing: Tile) -> void:
	await _resolve(await _respond(footing, TileEvent.EventType.ON_TURN_START), AddFamilyBoostEvent)


func test_war_footing_takes_no_dice() -> void:
	assert_ne(_tile("war_footing").activation_refusal(_die(3)), "")


func test_war_footing_builds_one_a_turn_for_red_tiles() -> void:
	var footing: Tile = _tile("war_footing")
	await _turn_starts(footing)
	await _turn_starts(footing)
	assert_eq(_boost(footing).bonus, 2)
	assert_eq(_hit_from(_tile("damage")).amount, 5, "a red tile hits harder")
	assert_eq(_hit_from(_tile("ratchet_cannon")).amount, 5, "every red tile")
	assert_eq(_hit_from(_tile("shield")).amount, 3, "a blue tile doesn't")
	assert_eq(_hit_from(_tile("damage"), 3, targeted).amount, 3, "nor does an enemy's own hit")


func test_war_footing_tops_out_at_five() -> void:
	var footing: Tile = _tile("war_footing")
	for i: int in 8:
		await _turn_starts(footing)
	assert_eq(_boost(footing).bonus, 5)


func test_war_footing_plus_builds_two_a_turn_to_six() -> void:
	var footing: Tile = _tile("war_footing_plus")
	await _turn_starts(footing)
	assert_eq(_boost(footing).bonus, 2)
	for i: int in 5:
		await _turn_starts(footing)
	assert_eq(_boost(footing).bonus, 6)


func test_a_hull_hit_knocks_war_footing_down_one() -> void:
	var footing: Tile = _tile("war_footing")
	await _turn_starts(footing)
	await _turn_starts(footing)
	await _resolve(await _respond(footing, TileEvent.EventType.ON_PLAYER_HEALTH_HIT), AddFamilyBoostEvent)
	assert_eq(_boost(footing).bonus, 1)
	await _resolve(await _respond(footing, TileEvent.EventType.ON_PLAYER_HEALTH_HIT), AddFamilyBoostEvent)
	assert_null(_boost(footing), "spent to nothing, it leaves play")


func test_a_hull_hit_with_nothing_built_does_nothing() -> void:
	var footing: Tile = _tile("war_footing")
	var events: Array[EffectEvent] = await _respond(footing, TileEvent.EventType.ON_PLAYER_HEALTH_HIT)
	assert_eq(_of(events, AddFamilyBoostEvent).size(), 0, "nothing queued, so the tile doesn't light up")


func test_two_war_footings_build_apart() -> void:
	var first: Tile = _tile("war_footing")
	var second: Tile = _tile("war_footing")
	for i: int in 5:
		await _turn_starts(first)
	await _turn_starts(second)
	assert_eq(_hit_from(_tile("damage")).amount, 3 + 5 + 1)


func test_war_footing_ends_with_the_fight() -> void:
	var footing: Tile = _tile("war_footing")
	await _turn_starts(footing)
	Events.combat_finished.emit()
	assert_null(_boost(footing))


func test_war_footing_shows_on_red_tiles_panels() -> void:
	var footing: Tile = _tile("war_footing")
	await _turn_starts(footing)
	var boost: FamilyBoostModifier = _boost(footing)
	assert_string_contains(boost.get_rule_info_text(_tile("damage")), "+1 damage")
	assert_eq(boost.get_rule_info_text(_tile("shield")), "")
	assert_string_contains(boost.get_info_text(), "War Footing +1")


# ── Status Catalyst ───────────────────────────────────────────────────────────

func test_status_catalyst_refuses_a_target_with_no_status() -> void:
	var tile: Tile = _tile("status_catalyst")
	assert_ne(tile.activation_refusal(_die(6)), "")
	await _apply(targeted, &"burn", 2)
	assert_eq(tile.activation_refusal(_die(6)), "")
	assert_ne(tile.activation_refusal(_die(5)), "", "the base takes only a 6")
	assert_eq(_tile("status_catalyst_plus").activation_refusal(_die(5)), "", "the upgrade takes a 5 too")


func test_status_catalyst_has_one_use_and_a_light_for_it() -> void:
	for tile_id: String in ["status_catalyst", "status_catalyst_plus"]:
		var resource: TileResource = load(TILES % tile_id)
		assert_eq(resource.uses_per_turn, 1)
		assert_eq(resource.textures.get_frame_count(&"default"), 2)


func test_status_catalyst_doubles_every_status_on_its_target() -> void:
	await _apply(targeted, &"burn", 3)
	await _apply(targeted, &"exposed", 1)
	await _apply(other, &"burn", 4)
	var events: Array[EffectEvent] = await _play(_tile("status_catalyst"), 6)
	assert_eq(_of(events, GiveDieToTargetEvent).size(), 1, "the die goes to the target")
	engine.injected.clear()
	await _resolve(events, MultiplyStatusesEvent)
	await _resolve(engine.injected.duplicate(), ApplyStatusEvent)
	assert_eq(_stacks(targeted, &"burn"), 6)
	assert_eq(_stacks(targeted, &"exposed"), 2)
	assert_eq(_stacks(other, &"burn"), 4, "only the target")


func test_multiplying_works_on_every_status_in_the_catalog() -> void:
	for status_id: StringName in StatusCatalog.ids():
		await _apply(targeted, status_id, 1)
	var event := MultiplyStatusesEvent.new()
	event.actor = Globals.player
	event.targets = [targeted] as Array[Node]
	await event.resolve(engine)
	var grown: Array[EffectEvent] = engine.injected_of(ApplyStatusEvent)
	assert_eq(grown.size(), StatusCatalog.ids().size(), "one application per status")
	for apply: EffectEvent in grown:
		assert_eq(apply.amount, 1)


# ── Hex Coil ──────────────────────────────────────────────────────────────────

func _hex_answers() -> Array[TileEventTriggeredEvent]:
	var answers: Array[TileEventTriggeredEvent] = []
	for event: EffectEvent in engine.injected_of(TileEventTriggeredEvent):
		answers.append(event as TileEventTriggeredEvent)
	return answers


func test_hex_coil_takes_no_dice() -> void:
	assert_ne(_tile("hex_coil").activation_refusal(_die(3)), "")


func test_hex_coil_hits_the_ship_you_put_a_status_on() -> void:
	_listening_tile("hex_coil")
	await _apply(other, &"burn", 2)
	var answers: Array[TileEventTriggeredEvent] = _hex_answers()
	assert_eq(answers.size(), 1)
	assert_eq(answers[0].subject, other)
	engine.injected.clear()
	await answers[0].resolve(engine)
	var hits: Array[EffectEvent] = engine.injected_of(DamageEvent)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].amount, 2)
	assert_eq(hits[0].targets, [other] as Array[Node], "that ship, not the target")
	assert_eq(engine.injected_of(ApplyStatusEvent).size(), 0, "its hit applies nothing, so it can't loop")


func test_hex_coil_plus_hits_for_three() -> void:
	_listening_tile("hex_coil_plus")
	await _apply(targeted, &"jammed", 1)
	var answer: TileEventTriggeredEvent = _hex_answers()[0]
	engine.injected.clear()
	await answer.resolve(engine)
	assert_eq(engine.injected_of(DamageEvent)[0].amount, 3)


func test_hex_coil_ignores_statuses_on_you_and_from_enemies() -> void:
	_listening_tile("hex_coil")
	await _apply(Globals.player, &"burn", 3)
	await _apply(targeted, &"burn", 3, other)
	assert_eq(_hex_answers().size(), 0)


func test_fume_vent_sets_hex_coil_off_once_per_enemy() -> void:
	_listening_tile("hex_coil")
	var vent: Tile = _tile("fume_vent")
	var burns: Array[EffectEvent] = await _respond(vent, TileEvent.EventType.ON_TURN_START)
	engine.injected.clear()
	await _resolve(burns, ApplyStatusEvent)
	var hit: Array[Node] = []
	for answer: TileEventTriggeredEvent in _hex_answers():
		hit.append(answer.subject)
	assert_eq(hit, [targeted, other] as Array[Node], "each enemy once, and not the vent's own ship")


func test_moving_your_statuses_onto_an_enemy_counts() -> void:
	_listening_tile("hex_coil")
	var player: Player = Globals.player
	engine.add_modifier(StatusCatalog.create(&"burn", player, 2))
	engine.add_modifier(StatusCatalog.create(&"jammed", player, 1))
	var move := TransferStatusesEvent.new()
	move.actor = player
	move.targets = [targeted] as Array[Node]
	await move.resolve(engine)
	assert_eq(_hex_answers().size(), 2, "one per status moved")


func test_status_catalyst_sets_hex_coil_off_once_per_status() -> void:
	await _apply(targeted, &"burn", 2)
	await _apply(targeted, &"weakened", 1)
	_listening_tile("hex_coil")
	var events: Array[EffectEvent] = await _play(_tile("status_catalyst"), 6)
	engine.injected.clear()
	await _resolve(events, MultiplyStatusesEvent)
	await _resolve(engine.injected.duplicate(), ApplyStatusEvent)
	assert_eq(_hex_answers().size(), 2)


# ── AutoPilot ─────────────────────────────────────────────────────────────────

func _on_grid(tiles: Array[Tile]) -> void:
	var grid: TileGrid = autofree(TileGrid.new())
	for i: int in tiles.size():
		grid.tile_locations[Vector2i(i, 0)] = tiles[i]
	Globals.tile_grid = grid


func test_the_forecast_counts_what_a_catalyst_adds() -> void:
	await _apply(targeted, &"burn", 3)
	var catalyst: Tile = _tile("status_catalyst")
	_on_grid([catalyst] as Array[Tile])
	var forecast: AutoPilotForecast = AutoPilotForecast.of(catalyst, _die(6), targeted)
	assert_almost_eq(forecast.statuses.get(&"burn", 0.0), 3.0, 0.01)


func test_the_forecast_counts_hex_coils_hit() -> void:
	var round: Tile = _tile("incendiary_round")
	_on_grid([round, _tile("hex_coil")] as Array[Tile])
	var forecast: AutoPilotForecast = AutoPilotForecast.of(round, _die(1), targeted)
	assert_almost_eq(forecast.damage.get(targeted, 0.0), 2.0, 0.01)
	assert_gt(forecast.statuses.get(&"burn", 0.0), 0.0)
