extends "res://test/helpers/die_fighter_test.gd"
## The defensive tiles play whole: Phase Cloak's Phased, which lets the next
## enemy hit pass through; Spiked Hull, which hits back at whatever attacks
## the player; and Blood Valve, which pays hull for a hologram.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const TILES: String = "res://Source/Content/Tiles/TileResources/%s.tres"

## Records the chains tiles play.
var recorder: RecordingEngine
## Resolves events for real, for the rules a status or event enforces.
var engine: ScenarioEngine
var player: Player
var enemy: Enemy
var other: Enemy


func before_each() -> void:
	super()
	recorder = autofree(RecordingEngine.new())
	engine = add_child_autofree(ScenarioEngine.new())
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = engine
	Globals.scenario_manager = manager
	var state: GameStateManager = autofree(GameStateManager.new())
	state.state = GameStateManager.GameState.IN_COMBAT
	Globals.state_manager = state
	player = add_child_autofree(PLAYER_SCENE.instantiate())
	player.health.max_health = 30
	player.health.health = 30
	player.health.shields = 0
	Globals.player = player
	enemy = _enemy()
	other = _enemy()
	var computer: TargetingComputer = autofree(TargetingComputer.new())
	computer.targeted_enemy = enemy
	Globals.targeting_computer = computer
	var roster: EnemyManager = autofree(EnemyManager.new())
	roster.enemies = [enemy, other] as Array[Enemy]
	Globals.enemy_manager = roster
	Globals.tile_grid = autofree(TileGrid.new())


func _enemy() -> Enemy:
	var ship: Enemy = autofree(ENEMY_SCENE.instantiate())
	ship.health.max_health = 40
	ship.health.health = 40
	ship.health.shields = 0
	ship.scenario_state = ScenarioShipState.new()
	# Intents are only readable while a hostile ship is present.
	ship.scenario_state.attitude = Enemy.Attitude.AGGRESSIVE
	return ship


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


## Plays [param tile_id]'s chain with a die of [param face] into the recorder
## and returns what it produced.
func _play(tile_id: String, face: int) -> Array[EffectEvent]:
	recorder.injected.clear()
	var tile: Tile = _tile(tile_id)
	Globals.tile_grid.tile_locations[Vector2i(1, 1)] = tile
	var context: EffectContext = EffectContext.new()
	context.actor = player
	context.effect_source = tile
	context.activator_die = _die(face)
	await tile.tile_resource.effect_chain.play(context, recorder)
	return recorder.injected.duplicate()


func _of(events: Array[EffectEvent], script: Script) -> Array[EffectEvent]:
	return events.filter(func(e: EffectEvent) -> bool: return is_instance_of(e, script))


## Runs [param event] the way the engine does: every modifier's before-hook,
## then the event itself unless one canceled it.
func _land(event: EffectEvent) -> void:
	for mod: Modifier in engine.modifiers.duplicate():
		if mod in engine.modifiers and not event.canceled:
			await mod.on_before_event(event, engine)
	if not event.canceled:
		await event.resolve(engine)


func _hit(from: Node, targets: Array[Node], amount: int) -> DamageEvent:
	var hit: DamageEvent = DamageEvent.new()
	hit.actor = from
	hit.effect_source = from
	hit.targets = targets
	hit.amount = amount
	return hit


func _apply(target: Node2D, status_id: StringName, stacks: int) -> void:
	var event: ApplyStatusEvent = ApplyStatusEvent.new()
	event.status_id = status_id
	event.amount = stacks
	event.targets = [target]
	await event.resolve(engine)


func _phased_on(ship: Node) -> int:
	var status: StatusModifier = engine.find_status(ship, &"phased")
	return status.stacks if status else 0


# ── Phase Cloak ───────────────────────────────────────────────────────────────

func test_phase_cloak_phases_you_and_hands_the_target_the_die() -> void:
	var events: Array[EffectEvent] = await _play("phase_cloak", 6)
	var applied: Array[EffectEvent] = _of(events, ApplyStatusEvent)
	assert_eq(applied.size(), 1)
	assert_eq((applied[0] as ApplyStatusEvent).status_id, &"phased")
	assert_eq(applied[0].amount, 1)
	assert_eq(applied[0].targets, [player] as Array[Node], "the cloak goes on you")
	var gives: Array[EffectEvent] = _of(events, GiveDieToTargetEvent)
	assert_eq(gives.size(), 1)
	assert_eq(gives[0].targets, [enemy] as Array[Node], "the core trade: the die goes to the target")


func test_phase_cloak_plus_phases_two_hits() -> void:
	var events: Array[EffectEvent] = await _play("phase_cloak_plus", 6)
	assert_eq(_of(events, ApplyStatusEvent)[0].amount, 2)


func test_phase_cloak_takes_only_a_six_in_a_fight_with_a_target() -> void:
	for face: int in range(1, 6):
		assert_false(_takes("phase_cloak", face), "turns away a %d" % face)
	assert_true(_takes("phase_cloak", 6))
	Globals.targeting_computer.targeted_enemy = null
	assert_false(_takes("phase_cloak", 6), "needs a ship to give the die to")
	Globals.targeting_computer.targeted_enemy = enemy
	Globals.state_manager.state = GameStateManager.GameState.OUT_OF_COMBAT
	assert_false(_takes("phase_cloak", 6), "nothing to dodge outside a fight")


func test_phased_lets_the_next_enemy_hit_through_shields_and_all() -> void:
	player.health.shields = 5
	await _apply(player, &"phased", 1)
	var hit: DamageEvent = _hit(enemy, [player] as Array[Node], 8)
	await _land(hit)
	assert_true(hit.canceled, "with nobody else aimed at, the hit misses outright")
	assert_eq(player.health.shields, 5, "the shields keep every point")
	assert_eq(player.health.health, 30)
	assert_eq(_phased_on(player), 0, "the stack is spent")

	await _land(_hit(enemy, [player] as Array[Node], 8))
	assert_eq(player.health.shields, 0, "the next hit lands")
	assert_eq(player.health.health, 27)


func test_phased_spends_one_stack_a_hit() -> void:
	await _apply(player, &"phased", 2)
	await _land(_hit(enemy, [player] as Array[Node], 4))
	assert_eq(_phased_on(player), 1)
	await _land(_hit(other, [player] as Array[Node], 4))
	assert_eq(_phased_on(player), 0)
	assert_eq(player.health.health, 30)


func test_phased_only_dodges_the_player_out_of_a_wider_hit() -> void:
	await _apply(player, &"phased", 1)
	var blast: DamageEvent = _hit(enemy, [player, other] as Array[Node], 5)
	await _land(blast)
	assert_false(blast.canceled)
	assert_eq(player.health.health, 30)
	assert_eq(other.health.health, 35, "the other ship still takes it")


func test_burn_and_your_own_tiles_get_through_phased() -> void:
	await _apply(player, &"phased", 1)
	# Burn on the player is their own fire: the player is its actor.
	await _land(_hit(player, [player] as Array[Node], 3))
	assert_eq(player.health.health, 27)
	var tile_cost: DamageEvent = _hit(player, [player] as Array[Node], 2)
	tile_cost.effect_source = _tile("ablative_charge")
	await _land(tile_cost)
	assert_eq(player.health.health, 25)
	assert_eq(_phased_on(player), 1, "still waiting for an enemy hit")


func test_a_zero_hit_does_not_spend_phased() -> void:
	await _apply(player, &"phased", 1)
	await _land(_hit(enemy, [player] as Array[Node], 0))
	assert_eq(_phased_on(player), 1)


func test_phased_beats_the_death_save_to_a_fatal_hit() -> void:
	player.engine_charge = player.max_engine_charge
	var save: EngineDeathSaveModifier = EngineDeathSaveModifier.new()
	engine.add_modifier(save)
	await _apply(player, &"phased", 1)
	await _land(_hit(enemy, [player] as Array[Node], 99))
	assert_eq(player.health.health, 30)
	assert_eq(player.engine_charge, player.max_engine_charge, "the drive isn't dumped on a hit that missed")


func test_phased_on_the_player_wears_off_as_the_enemy_turn_ends() -> void:
	await _apply(player, &"phased", 2)
	engine.tick_statuses()
	assert_eq(_phased_on(player), 2, "the enemies' tick, before they act, leaves it")
	engine.tick_statuses(true)
	assert_eq(_phased_on(player), 0, "gone by your next turn, however many stacks were left")


func test_phased_on_an_enemy_dodges_a_tile_hit_but_not_another_ship() -> void:
	await _apply(enemy, &"phased", 1)
	await _land(_hit(other, [enemy] as Array[Node], 5))
	assert_eq(enemy.health.health, 35, "another ship's hit isn't the player's")
	var shot: DamageEvent = _hit(player, [enemy] as Array[Node], 6)
	shot.effect_source = _tile("damage")
	await _land(shot)
	assert_eq(enemy.health.health, 35)
	assert_eq(_phased_on(enemy), 0)


func test_phased_has_a_badge_and_a_rule_on_either_side() -> void:
	await _apply(player, &"phased", 1)
	assert_eq(player.get_status_bar().get_child_count(), 1, "the cloak shows on your status bar")
	assert_eq(StatusCatalog.create(&"phased", player, 1).rule_term(), "Phased (you)")
	assert_false(Keywords.definition("Phased").is_empty())


# ── AutoPilot ────────────────────────────────────────────────────────────────

func _attack(amount: int) -> EnemyActionResource:
	var attack: EnemyActionResource = preload("res://test/helpers/ships.gd").attack()
	attack.intent_amount = amount
	return attack


func _idle() -> EnemyActionResource:
	var empty: Array[EffectData] = []
	return preload("res://test/helpers/ships.gd").action("Idle", empty)


func _hold(ship: Enemy, face: int) -> void:
	ship.dice_manager.add(_die(face))


func test_a_cloak_is_worth_the_biggest_hits_coming() -> void:
	preload("res://test/helpers/ships.gd").set_table(enemy,
		[_idle(), _attack(3), _idle(), _idle(), _idle(), _attack(9)])
	preload("res://test/helpers/ships.gd").set_table(other,
		[_idle(), _attack(5), _idle(), _idle(), _idle(), _idle()])
	assert_eq(AutoPilotThreat.phased_worth(1), 0.0, "nothing held, nothing to dodge")
	_hold(enemy, 2)
	_hold(enemy, 6)
	_hold(other, 2)
	_hold(other, 1)
	assert_eq(AutoPilotThreat.phased_worth(1), 9.0)
	assert_eq(AutoPilotThreat.phased_worth(2), 14.0)
	assert_eq(AutoPilotThreat.phased_worth(5), 17.0, "only as many hits as are coming")
	await _apply(player, &"phased", 1)
	assert_eq(AutoPilotThreat.phased_worth(1), 5.0, "the cloak already up takes the biggest")


func test_the_forecast_values_a_cloak_as_shields() -> void:
	preload("res://test/helpers/ships.gd").set_table(enemy,
		[_idle(), _idle(), _idle(), _idle(), _idle(), _attack(7)])
	_hold(enemy, 6)
	var forecast: AutoPilotForecast = AutoPilotForecast.of(_tile("phase_cloak"), _die(6), enemy,
		[enemy] as Array[Enemy])
	assert_eq(forecast.shields, 7.0)
	assert_eq(forecast.handoffs.size(), 1)


# ── Spiked Hull ───────────────────────────────────────────────────────────────

## Who attacked the player, in order, while [method _watch_attacks] listens.
var attackers: Array[Enemy] = []


func _watch_attacks() -> void:
	attackers.clear()
	Events.player_attacked.connect(_on_attacked)


func _on_attacked(attacker: Enemy) -> void:
	attackers.append(attacker)


func after_each() -> void:
	if Events.player_attacked.is_connected(_on_attacked):
		Events.player_attacked.disconnect(_on_attacked)
	super()


## A Spiked Hull (or [param tile_id]) on the grid and listening, with the
## engine swapped for the recorder so its response can be read back.
func _spikes(tile_id: String = "spiked_hull") -> Tile:
	# In the tree, so it hooks the events it answers.
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


func test_an_enemy_hit_counts_as_an_attack_even_when_the_shields_take_it() -> void:
	_watch_attacks()
	player.health.shields = 10
	await _land(_hit(enemy, [player] as Array[Node], 4))
	assert_eq(player.health.health, 30, "the shields took it all")
	assert_eq(attackers, [enemy] as Array[Enemy])


func test_one_hit_is_one_attack_however_big_or_wide() -> void:
	_watch_attacks()
	await _land(_hit(enemy, [player, other] as Array[Node], 9))
	assert_eq(attackers, [enemy] as Array[Enemy])


func test_ion_fire_is_an_attack() -> void:
	_watch_attacks()
	player.health.shields = 6
	var ion: IonDamageEvent = IonDamageEvent.new()
	ion.actor = enemy
	ion.effect_source = enemy
	ion.targets = [player] as Array[Node]
	ion.amount = 2
	await _land(ion)
	assert_eq(attackers, [enemy] as Array[Enemy])


func test_burn_your_own_tiles_and_ships_fighting_each_other_are_not_attacks_on_you() -> void:
	_watch_attacks()
	await _land(_hit(player, [player] as Array[Node], 2))
	await _land(_hit(enemy, [other] as Array[Node], 2))
	var thorn: DamageEvent = _hit(player, [enemy] as Array[Node], 2)
	thorn.effect_source = _tile("damage")
	await _land(thorn)
	assert_eq(attackers.size(), 0)


func test_a_phased_hit_never_reached_you_so_it_is_no_attack() -> void:
	_watch_attacks()
	await _apply(player, &"phased", 1)
	await _land(_hit(enemy, [player] as Array[Node], 5))
	assert_eq(attackers.size(), 0)


func test_spiked_hull_hits_back_at_the_attacker() -> void:
	_spikes()
	player.health.shields = 10
	Events.player_attacked.emit(enemy)
	var triggered: Array[EffectEvent] = _of(recorder.injected, TileEventTriggeredEvent)
	assert_eq(triggered.size(), 1, "queued, behind the rest of the attacker's chain")
	var events: Array[EffectEvent] = await _responses()
	var hits: Array[EffectEvent] = _of(events, DamageEvent)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].amount, 2)
	assert_eq(hits[0].targets, [enemy] as Array[Node], "the attacker, not the target or a random ship")
	assert_eq(hits[0].actor, player, "your hit, so it can't set off another attack on you")


func test_spiked_hull_plus_hits_for_three() -> void:
	_spikes("spiked_hull_plus")
	Events.player_attacked.emit(other)
	var hits: Array[EffectEvent] = _of(await _responses(), DamageEvent)
	assert_eq(hits[0].amount, 3)
	assert_eq(hits[0].targets, [other] as Array[Node])


func test_spiked_hull_hits_nothing_once_the_attacker_is_gone() -> void:
	_spikes()
	Events.player_attacked.emit(enemy)
	Events.player_attacked.emit(other)
	# Before the responses play, one attacker dies and the other flees.
	enemy.health.health = 0
	Globals.enemy_manager.enemies.erase(other)
	assert_eq(_of(recorder.injected, TileEventTriggeredEvent).size(), 2)
	var struck: Array[Node] = []
	for hit: EffectEvent in _of(await _responses(), DamageEvent):
		struck.append_array(hit.targets)
	assert_eq(struck.size(), 0, "a wreck or a ship that fled isn't hit")


func test_spiked_hull_takes_no_dice() -> void:
	for face: int in range(1, 7):
		assert_false(_takes("spiked_hull", face))


# ── Blood Valve ───────────────────────────────────────────────────────────────

func _spend_hull(amount: int) -> SpendHullEvent:
	var cost: SpendHullEvent = SpendHullEvent.new()
	cost.actor = player
	cost.targets = [player] as Array[Node]
	cost.amount = amount
	return cost


func test_blood_valve_pays_hull_for_a_hologram_and_returns_the_die() -> void:
	var events: Array[EffectEvent] = await _play("blood_valve", 5)
	var costs: Array[EffectEvent] = _of(events, SpendHullEvent)
	assert_eq(costs.size(), 1)
	assert_eq(costs[0].amount, 3)
	var holograms: Array[EffectEvent] = _of(events, SpawnHolographicDieEvent)
	assert_eq(holograms.size(), 1)
	assert_eq(holograms[0].amount, 5, "a copy of the die")
	assert_eq(_of(events, GiveDieToPlayerEvent).size(), 1, "the die comes back")
	assert_eq(_of(events, GiveDieToTargetEvent).size(), 0)
	assert_eq(events.find(costs[0]) < events.find(holograms[0]), true, "it pays first")


func test_blood_valve_plus_costs_two() -> void:
	var events: Array[EffectEvent] = await _play("blood_valve_plus", 2)
	assert_eq(_of(events, SpendHullEvent)[0].amount, 2)


func test_blood_valve_refuses_a_die_it_would_kill_you_paying_for() -> void:
	assert_true(_takes("blood_valve", 1), "takes any die")
	player.health.health = 4
	assert_true(_takes("blood_valve", 6), "4 hull pays 3 and leaves 1")
	player.health.health = 3
	assert_false(_takes("blood_valve", 6))
	assert_true(_takes("blood_valve_plus", 6), "the cheaper valve still can")
	player.health.health = 30
	Globals.state_manager.state = GameStateManager.GameState.OUT_OF_COMBAT
	assert_false(_takes("blood_valve", 6), "a hologram is no use outside a fight")


func test_blood_valve_ignores_echo() -> void:
	assert_false(_tile("blood_valve").tile_resource.can_be_echoed,
		"one payment, one hologram: an echo would double the cost past the hull check")
	assert_false(_tile("blood_valve_plus").tile_resource.can_be_echoed)


func test_spending_hull_goes_past_the_shields_and_is_a_hull_hit() -> void:
	player.health.shields = 10
	var hits: Array[int] = [0]
	var count_hit: Callable = func() -> void: hits[0] += 1
	Events.player_health_hit.connect(count_hit)
	await _land(_spend_hull(3))
	Events.player_health_hit.disconnect(count_hit)
	assert_eq(player.health.health, 27)
	assert_eq(player.health.shields, 10, "the shields don't pay it")
	assert_eq(hits[0], 1, "Spite Coil, Reactive Armor and Regenerative Brake hear it")


func test_spending_hull_is_no_attack_and_nothing_dodges_it() -> void:
	_watch_attacks()
	await _apply(player, &"phased", 1)
	await _land(_spend_hull(3))
	assert_eq(player.health.health, 27)
	assert_eq(_phased_on(player), 1, "the cloak is still waiting for an enemy")
	assert_eq(attackers.size(), 0)
	assert_false(_spend_hull(3).is_amplifiable(), "a price, not an output")


func test_spending_hull_refuses_rather_than_kill() -> void:
	player.health.health = 3
	await _land(_spend_hull(3))
	assert_eq(player.health.health, 3)
	assert_false(player.health.is_dead)


func test_the_forecast_counts_the_hull_paid_and_both_dice_back() -> void:
	var forecast: AutoPilotForecast = AutoPilotForecast.of(_tile("blood_valve"), _die(4), enemy,
		[enemy] as Array[Enemy])
	assert_eq(forecast.damage.get(player, 0.0), 3.0)
	assert_eq(forecast.dice_back, 2.0, "the die and its hologram")
	assert_eq(forecast.handoffs.size(), 0)


# ── Counterweight Battery ─────────────────────────────────────────────────────

## Plays [param tile_id]'s first event response into the recorder.
func _respond(tile_id: String) -> Array[EffectEvent]:
	recorder.injected.clear()
	var tile: Tile = _tile(tile_id)
	Globals.tile_grid.tile_locations[Vector2i(1, 1)] = tile
	var context: EffectContext = EffectContext.new()
	context.actor = player
	context.effect_source = tile
	var chain: EffectChain = tile.tile_resource.event_responses.values()[0]
	await chain.play(context, recorder)
	return recorder.injected.duplicate()


func test_counterweight_battery_turns_two_charge_into_shields() -> void:
	player.engine_charge = 3
	var events: Array[EffectEvent] = await _respond("counterweight_battery")
	var spends: Array[EffectEvent] = _of(events, SpendEngineChargeEvent)
	var shields: Array[EffectEvent] = _of(events, ShieldEvent)
	assert_eq(spends.size(), 1)
	assert_eq(shields.size(), 1)
	if spends.size() == 1 and shields.size() == 1:
		assert_eq(spends[0].amount, 2)
		assert_eq(shields[0].amount, 5)
		assert_eq(shields[0].targets, [player] as Array[Node2D])


func test_counterweight_battery_does_nothing_without_the_charge() -> void:
	player.engine_charge = 1
	var events: Array[EffectEvent] = await _respond("counterweight_battery")
	assert_true(_of(events, ShieldEvent).is_empty(), "no free shields")
	assert_true(_of(events, SpendEngineChargeEvent).is_empty())


func test_counterweight_battery_plus_pays_the_same_for_more() -> void:
	player.engine_charge = 2
	var events: Array[EffectEvent] = await _respond("counterweight_battery_plus")
	var spends: Array[EffectEvent] = _of(events, SpendEngineChargeEvent)
	var shields: Array[EffectEvent] = _of(events, ShieldEvent)
	assert_eq(spends.size(), 1)
	assert_eq(shields.size(), 1)
	if spends.size() == 1 and shields.size() == 1:
		assert_eq(spends[0].amount, 2)
		assert_eq(shields[0].amount, 7)


# ── Heat Sink ─────────────────────────────────────────────────────────────────

func test_heat_sink_refuses_a_target_with_no_burn() -> void:
	assert_false(_takes("heat_sink", 4), "nothing to cash in")
	await _apply(enemy, &"burn", 3)
	assert_true(_takes("heat_sink", 4))
