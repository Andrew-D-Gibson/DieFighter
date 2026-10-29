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
