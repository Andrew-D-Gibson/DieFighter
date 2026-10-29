extends "res://test/helpers/die_fighter_test.gd"
## Delayed effects: things set up on one turn of a fight to happen on a later
## one (DelayedEffect). The countdown runs on the player's turn starts, and a
## delay never outlives its fight. HeldDieDelay keeps a die on a tile until
## then; DelayedPayload plants a payload on a ship, moves it when the ship
## leaves, and plays it when its turn comes.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const WELDER: TileResource = preload("res://Source/Content/Tiles/TileResources/welder.tres")


## Counts how often it came due or was dropped.
class CountingDelay:
	extends DelayedEffect
	var due: int = 0
	var dropped: int = 0
	var ticks: int = 0

	func _on_due(_engine_now: ScenarioEngine) -> void:
		due += 1

	func _on_dropped() -> void:
		dropped += 1

	func _on_turns_changed() -> void:
		ticks += 1


var engine: RecordingEngine
var state: GameStateManager


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = engine
	Globals.scenario_manager = manager
	state = autofree(GameStateManager.new())
	Globals.state_manager = state
	state.state = GameStateManager.GameState.IN_COMBAT


func after_each() -> void:
	# Takes out anything still listening for turn starts.
	engine.clear_modifiers()
	super()


func _delay(turns: int) -> CountingDelay:
	var delay := CountingDelay.new()
	delay.turns_left = turns
	engine.add_modifier(delay)
	return delay


func _enemy(hostile: bool = true) -> Enemy:
	var ship: Enemy = autofree(ENEMY_SCENE.instantiate())
	ship.health.max_health = 40
	ship.health.health = 40
	ship.scenario_state = ScenarioShipState.new()
	ship.scenario_state.attitude = Enemy.Attitude.AGGRESSIVE if hostile else Enemy.Attitude.NEUTRAL
	return ship


func _payload(turns: int) -> DelayedEffectData:
	var data := DelayedEffectData.new()
	data.category = EffectEnums.Category.UTILITY
	data.subtype = EffectEnums.UtilitySubtype.DELAY_EFFECTS
	data.amount = turns
	data.badge_title = "Test Bomb"
	data.badge_text = "Deal {amount} damage"
	data.delayed_effects = [Effects.damage()] as Array[EffectData]
	return data


func _arm(host: Enemy, turns: int, amount: int) -> DelayedPayload:
	var event := ArmDelayedPayloadEvent.new()
	event.targets = [host]
	event.amount = amount
	event.payload = _payload(turns)
	await event.resolve(engine)
	return _payloads()[0] if not _payloads().is_empty() else null


func _payloads() -> Array[DelayedPayload]:
	var found: Array[DelayedPayload] = []
	for delay: DelayedEffect in DelayedEffect.all_in(engine):
		if delay is DelayedPayload:
			found.append(delay as DelayedPayload)
	return found


# ── The countdown ─────────────────────────────────────────────────────────────

func test_it_comes_due_on_the_turn_start_its_count_reaches() -> void:
	var delay: CountingDelay = _delay(2)
	Events.player_turn_refresh.emit()
	assert_eq(delay.due, 0, "one turn still to go")
	assert_eq(delay.turns_left, 1)
	assert_eq(delay.ticks, 1)
	Events.player_turn_refresh.emit()
	assert_eq(delay.due, 1)
	assert_false(delay.is_pending(), "it leaves the engine as it goes off")
	Events.player_turn_refresh.emit()
	assert_eq(delay.due, 1, "once only")


func test_a_fights_opening_turn_doesnt_count() -> void:
	var delay: CountingDelay = _delay(1)
	Events.first_turn_start.emit()
	assert_eq(delay.due, 0)
	assert_eq(delay.turns_left, 1)


func test_the_fight_ending_drops_it() -> void:
	var delay: CountingDelay = _delay(1)
	state.state = GameStateManager.GameState.OUT_OF_COMBAT
	assert_eq(delay.dropped, 1)
	assert_false(delay.is_pending())
	Events.player_turn_refresh.emit()
	assert_eq(delay.due, 0, "never goes off after the fight")


func test_a_turn_starting_out_of_a_fight_drops_it() -> void:
	var delay: CountingDelay = _delay(1)
	# A turn handed back after an enemy turn run out of combat.
	Globals.state_manager = null
	Events.player_turn_refresh.emit()
	assert_eq(delay.due, 0)
	assert_eq(delay.dropped, 1)


func test_a_jump_shutting_the_engine_down_drops_it_silently() -> void:
	var delay: CountingDelay = _delay(1)
	engine.shutdown()
	Events.player_turn_refresh.emit()
	assert_eq(delay.due, 0)
	assert_false(delay.is_pending())


# ── Holding a die over ────────────────────────────────────────────────────────

func _player() -> Player:
	var player: Player = add_child_autofree(PLAYER_SCENE.instantiate())
	player.num_of_dice = 3
	Globals.player = player
	return player


func _bay() -> Tile:
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = WELDER
	return add_child_autofree(tile)


func _die(player: Player, face: int) -> Dice:
	var die: Dice = DICE_SCENE.instantiate()
	die.value = face
	player.add_child(die)
	return die


func _hold(tile: Tile, die: Dice, turns: int = 1) -> void:
	var event := HoldDieForTurnsEvent.new()
	event.effect_source = tile
	event.activator_die = die
	event.amount = turns
	await event.resolve(engine)


func test_a_held_die_stays_on_its_tile_through_the_turn_end() -> void:
	var player: Player = _player()
	var bay: Tile = _bay()
	var die: Dice = _die(player, 5)
	await _hold(bay, die)
	assert_true(die in bay.dice_queue.queue)
	assert_true(bay.is_holding_over(die))
	Events.player_turn_over.emit()
	assert_true(die in bay.dice_queue.queue, "not handed back with the turn's held dice")
	assert_false(die in player.dice_manager.queue)


func test_a_held_die_comes_home_at_its_face_as_the_next_turn_starts() -> void:
	var player: Player = _player()
	var bay: Tile = _bay()
	var die: Dice = _die(player, 5)
	await _hold(bay, die)
	Events.player_turn_over.emit()
	Events.player_turn_refresh.emit()
	assert_true(die in player.dice_manager.queue)
	assert_eq(die.value, 5, "kept at its face")
	assert_false(bay.is_holding_over(die))
	assert_true(DelayedEffect.all_in(engine).is_empty())


func test_a_die_held_for_two_turns_waits_two() -> void:
	var player: Player = _player()
	var bay: Tile = _bay()
	var die: Dice = _die(player, 2)
	await _hold(bay, die, 2)
	Events.player_turn_over.emit()
	Events.player_turn_refresh.emit()
	assert_true(die in bay.dice_queue.queue)
	Events.player_turn_over.emit()
	Events.player_turn_refresh.emit()
	assert_true(die in player.dice_manager.queue)


func test_a_die_kept_only_for_the_turn_still_goes_home_beside_a_held_one() -> void:
	var player: Player = _player()
	var bay: Tile = _bay()
	var held: Dice = _die(player, 6)
	var welded: Dice = _die(player, 3)
	await _hold(bay, held)
	bay.dice_queue.add(welded, true, false)
	Events.player_turn_over.emit()
	assert_true(welded in player.dice_manager.queue)
	assert_true(held in bay.dice_queue.queue)


func test_the_fight_ending_hands_a_held_die_back_at_once() -> void:
	var player: Player = _player()
	var bay: Tile = _bay()
	var die: Dice = _die(player, 4)
	await _hold(bay, die)
	state.state = GameStateManager.GameState.OUT_OF_COMBAT
	assert_true(die in player.dice_manager.queue)
	assert_false(bay.is_holding_over(die))
	assert_true(DelayedEffect.all_in(engine).is_empty())


func test_a_held_die_still_counts_as_owned_but_not_as_in_hand() -> void:
	var player: Player = _player()
	var bay: Tile = _bay()
	var die: Dice = _die(player, 4)
	die.holographic = true
	await _hold(bay, die)
	assert_eq(player.dice_owned(), 4, "3 real dice plus the held hologram")
	assert_eq(player.dice_manager.queue.size(), 0)


func test_a_held_die_taken_off_the_tile_early_is_left_alone() -> void:
	var player: Player = _player()
	var bay: Tile = _bay()
	var other: Tile = _bay()
	var die: Dice = _die(player, 4)
	await _hold(bay, die)
	other.dice_queue.add(die, true, false)
	assert_false(bay.is_holding_over(die))
	Events.player_turn_refresh.emit()
	assert_true(die in other.dice_queue.queue, "the delay doesn't snatch it back")


# ── A payload planted on a ship ───────────────────────────────────────────────

func test_arming_plants_a_badge_on_the_ship() -> void:
	var ship: Enemy = _enemy()
	var armed: DelayedPayload = await _arm(ship, 2, 20)
	assert_not_null(armed)
	assert_eq(armed.affected_node, ship)
	assert_eq(armed.amount, 20)
	assert_eq(armed.turns_left, 2)
	var badges: Array = ship.get_status_bar().get_children().filter(
			func(n: Node) -> bool: return n is DelayBadge)
	assert_eq(badges.size(), 1)
	assert_string_contains(armed.get_info_text(), "Deal 20 damage")


func test_it_goes_off_against_its_ship_with_the_armed_amount() -> void:
	var ship: Enemy = _enemy()
	await _arm(ship, 2, 20)
	Events.player_turn_refresh.emit()
	assert_eq(engine.injected_of(DelayedPayloadEvent).size(), 0)
	Events.player_turn_refresh.emit()
	var fired: Array[EffectEvent] = engine.injected_of(DelayedPayloadEvent)
	assert_eq(fired.size(), 1)
	assert_eq(fired[0].targets, [ship] as Array[Node])
	assert_eq(fired[0].amount, 20)

	engine.injected.clear()
	await fired[0].resolve(engine)
	var hits: Array[EffectEvent] = engine.injected_of(DamageEvent)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].amount, 20)
	assert_eq(hits[0].targets, [ship] as Array[Node])
	assert_true(ship.get_status_bar().get_children().all(
			func(n: Node) -> bool: return n is not DelayBadge or n.is_queued_for_deletion()),
			"the badge goes with it")


func test_its_ship_leaving_moves_it_to_another_hostile_one() -> void:
	var ship: Enemy = _enemy()
	var friend: Enemy = _enemy(false)
	var next: Enemy = _enemy()
	var roster: EnemyManager = autofree(EnemyManager.new())
	roster.enemies = [ship, friend, next] as Array[Enemy]
	Globals.enemy_manager = roster
	var armed: DelayedPayload = await _arm(ship, 2, 12)
	Events.enemy_left.emit(ship, ScenarioManager.Faction.PIRATE)
	assert_true(armed.is_pending())
	assert_eq(armed.affected_node, next, "never the neutral ship")
	assert_eq(armed.turns_left, 2, "the count carries over")


func test_with_no_hostile_ship_left_it_fizzles() -> void:
	var ship: Enemy = _enemy()
	var friend: Enemy = _enemy(false)
	var roster: EnemyManager = autofree(EnemyManager.new())
	roster.enemies = [ship, friend] as Array[Enemy]
	Globals.enemy_manager = roster
	var armed: DelayedPayload = await _arm(ship, 1, 12)
	Events.enemy_left.emit(ship, ScenarioManager.Faction.PIRATE)
	assert_false(armed.is_pending())
	Events.player_turn_refresh.emit()
	assert_eq(engine.injected_of(DelayedPayloadEvent).size(), 0)


func test_an_armed_payload_never_outlasts_the_fight() -> void:
	var ship: Enemy = _enemy()
	var armed: DelayedPayload = await _arm(ship, 1, 12)
	state.state = GameStateManager.GameState.OUT_OF_COMBAT
	assert_false(armed.is_pending())
	Events.player_turn_refresh.emit()
	assert_eq(engine.injected_of(DelayedPayloadEvent).size(), 0)


func test_the_handler_captures_the_first_target_and_running_amount() -> void:
	var ship: Enemy = _enemy()
	var data: DelayedEffectData = _payload(2)
	var context := EffectContext.new()
	context.targets = [ship]
	context.running_amount = 18
	await DelayEffectsHandler.new().apply(data, context, engine)
	var armed: Array[EffectEvent] = engine.injected_of(ArmDelayedPayloadEvent)
	assert_eq(armed.size(), 1)
	assert_eq(armed[0].amount, 18)
	assert_false(armed[0].is_amplifiable(), "an Amplifier acts on the hit when it lands")


func test_the_handler_does_nothing_without_a_target() -> void:
	var context := EffectContext.new()
	context.running_amount = 18
	await DelayEffectsHandler.new().apply(_payload(2), context, engine)
	assert_eq(engine.injected.size(), 0)
