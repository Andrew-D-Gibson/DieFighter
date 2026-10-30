extends "res://test/helpers/die_fighter_test.gd"
## The engines' evasion: each enemy hit on the player has a chance to miss,
## 3% per point of charge up to 50%, rolled from its own seeded stream.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")

var engine: ScenarioEngine
var evasion: EvasionModifier
var player: Player
var enemy: Enemy
var other: Enemy


func before_each() -> void:
	super()
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
	player.num_of_dice = 3
	player.engine_charge = 0
	Globals.player = player
	enemy = _enemy()
	other = _enemy()
	evasion = EvasionModifier.new()
	engine.add_modifier(evasion)


func _enemy() -> Enemy:
	var ship: Enemy = autofree(ENEMY_SCENE.instantiate())
	ship.health.max_health = 40
	ship.health.health = 40
	ship.health.shields = 0
	ship.scenario_state = ScenarioShipState.new()
	ship.scenario_state.attitude = Enemy.Attitude.AGGRESSIVE
	return ship


func _rng() -> RandomNumberGenerator:
	return RNGManager.get_rng(RNGManager.Bucket.EVASION)


## Seeds the evasion stream so its next roll does (or doesn't) come in under
## [param chance], and returns the state to compare against afterwards.
func _seed_roll(dodges: bool, chance: int) -> int:
	var rng: RandomNumberGenerator = _rng()
	for candidate: int in range(1, 1000):
		rng.seed = candidate
		var start: int = rng.state
		var roll: int = rng.randi_range(1, 100)
		rng.state = start
		if (roll <= chance) == dodges:
			return start
	fail_test("no seed gives that roll")
	return 0


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


# ── The chance ────────────────────────────────────────────────────────────────

func test_each_point_of_charge_is_three_percent() -> void:
	assert_eq(evasion.chance_percent(), 0, "a cold drive dodges nothing")
	player.engine_charge = 4
	assert_eq(evasion.chance_percent(), 12)
	player.engine_charge = player.max_engine_charge
	assert_eq(evasion.chance_percent(), 30, "a full 3-dice drive is 30%")


func test_the_chance_stops_at_fifty_percent() -> void:
	player.num_of_dice = 6
	player.engine_charge = player.max_engine_charge
	assert_eq(evasion.chance_percent(), 50)
	evasion.add_bonus(20)
	assert_eq(evasion.chance_percent(), 50, "a bonus can't push it past the cap")


func test_redline_charge_adds_nothing() -> void:
	player.engine_charge = player.max_engine_charge + 3
	assert_true(player.is_overcharged())
	assert_eq(evasion.chance_percent(), 30)


func test_a_bonus_lasts_until_the_enemy_turn_ends() -> void:
	evasion.add_bonus(12)
	assert_eq(evasion.chance_percent(), 12, "works even on a cold drive")
	Events.enemy_turn_over.emit()
	assert_eq(evasion.chance_percent(), 0)
	evasion.add_bonus(8)
	Events.combat_finished.emit()
	assert_eq(evasion.chance_percent(), 0, "and never outlasts the fight")


# ── Hits ─────────────────────────────────────────────────────────────────────

func test_an_evaded_hit_misses_outright() -> void:
	watch_signals(Events)
	player.engine_charge = player.max_engine_charge
	player.health.shields = 5
	_seed_roll(true, evasion.chance_percent())
	var hit: DamageEvent = _hit(enemy, [player] as Array[Node], 8)
	await _land(hit)
	assert_true(hit.canceled, "with nobody else aimed at, the hit misses outright")
	assert_eq(player.health.shields, 5, "the shields keep every point")
	assert_eq(player.health.health, 30)
	assert_signal_emitted_with_parameters(Events, "player_evaded", [enemy])
	assert_signal_not_emitted(Events, "player_attacked", "a miss isn't an attack on you")


func test_a_failed_roll_lets_the_hit_land() -> void:
	watch_signals(Events)
	player.engine_charge = player.max_engine_charge
	_seed_roll(false, evasion.chance_percent())
	await _land(_hit(enemy, [player] as Array[Node], 8))
	assert_eq(player.health.health, 22)
	assert_signal_not_emitted(Events, "player_evaded")


func test_a_cold_drive_never_rolls() -> void:
	var start: int = _rng().state
	await _land(_hit(enemy, [player] as Array[Node], 4))
	assert_eq(player.health.health, 26)
	assert_eq(_rng().state, start, "no roll drawn at 0%")


func test_evading_only_takes_the_player_out_of_a_wider_hit() -> void:
	player.engine_charge = player.max_engine_charge
	_seed_roll(true, evasion.chance_percent())
	var blast: DamageEvent = _hit(enemy, [player, other] as Array[Node], 5)
	await _land(blast)
	assert_false(blast.canceled)
	assert_eq(player.health.health, 30)
	assert_eq(other.health.health, 35, "the other ship still takes it")


func test_your_own_fire_is_never_evaded_or_rolled_for() -> void:
	player.engine_charge = player.max_engine_charge
	var start: int = _seed_roll(true, evasion.chance_percent())
	# Burn on the player is their own fire: the player is its actor.
	await _land(_hit(player, [player] as Array[Node], 3))
	assert_eq(player.health.health, 27)
	assert_eq(_rng().state, start)


func test_a_zero_hit_is_not_rolled_for() -> void:
	player.engine_charge = player.max_engine_charge
	var start: int = _rng().state
	await _land(_hit(enemy, [player] as Array[Node], 0))
	assert_eq(_rng().state, start)


func test_phased_takes_the_hit_before_a_roll_is_wasted() -> void:
	player.engine_charge = player.max_engine_charge
	var start: int = _rng().state
	var cloak: ApplyStatusEvent = ApplyStatusEvent.new()
	cloak.status_id = &"phased"
	cloak.amount = 1
	cloak.targets = [player] as Array[Node]
	await cloak.resolve(engine)
	await _land(_hit(enemy, [player] as Array[Node], 6))
	assert_eq(player.health.health, 30)
	assert_null(engine.find_status(player, &"phased"), "the cloak is spent")
	assert_eq(_rng().state, start, "and the dice weren't rolled for it")


func test_an_evaded_killing_blow_keeps_the_drive() -> void:
	player.engine_charge = player.max_engine_charge
	engine.add_modifier(EngineDeathSaveModifier.new())
	_seed_roll(true, evasion.chance_percent())
	await _land(_hit(enemy, [player] as Array[Node], 99))
	assert_eq(player.health.health, 30)
	assert_eq(player.engine_charge, player.max_engine_charge, "the save never saw a blow to catch")


func test_the_same_seed_dodges_the_same_hits() -> void:
	player.engine_charge = 7
	var outcomes: Array[bool] = []
	for pass_index: int in 2:
		_rng().seed = 4242
		var dodged: Array[bool] = []
		for i: int in 12:
			var hit: DamageEvent = _hit(enemy, [player] as Array[Node], 1)
			player.health.health = 30
			await _land(hit)
			dodged.append(hit.canceled)
		if pass_index == 0:
			outcomes = dodged
		else:
			assert_eq(dodged, outcomes)
	assert_true(outcomes.has(true) and outcomes.has(false), "21% over 12 hits should show both")


# ── Display ──────────────────────────────────────────────────────────────────

func test_the_chance_shows_on_the_engine_tile_only() -> void:
	var charger: Node2D = add_child_autofree(Node2D.new())
	charger.add_to_group(&"engine_charger")
	var tile: Tile = TILE_SCENE.instantiate()
	tile.name = "EngineChargerTile"
	tile.tile_resource = load("res://Source/Content/Tiles/MapTileResources/engine_charger.tres")
	charger.add_child(tile)
	var bystander: Tile = TILE_SCENE.instantiate()
	bystander.tile_resource = load("res://Source/Content/Tiles/TileResources/damage.tres")
	add_child_autofree(bystander)
	player.engine_charge = 5

	assert_eq(EvasionModifier.engine_display(player), tile)
	assert_string_contains(evasion.get_rule_info_text(tile), "15%")
	assert_eq(evasion.get_rule_info_text(bystander), "")
	assert_false(Keywords.definition("Evasion").is_empty())
