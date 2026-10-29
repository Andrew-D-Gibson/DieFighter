extends "res://test/helpers/die_fighter_test.gd"
## The twin-dice tiles (TileResource.holds_first_die): the first die is held,
## the next pays out. Played whole through TileActivationEvent, so the use
## budget, the activation checks and the hold all run as in a game. The
## engine records instead of resolving; the hold and hand-off events are
## resolved by hand so the dice really move.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const INTERCEPTOR: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/interceptor.tres")
const TILES: String = "res://Source/Content/Tiles/TileResources/%s.tres"

var engine: RecordingEngine
var enemy: Enemy
var player: Player


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = engine
	Globals.scenario_manager = manager
	player = add_child_autofree(PLAYER_SCENE.instantiate())
	Globals.player = player
	enemy = ENEMY_SCENE.instantiate()
	enemy.enemy_resource = INTERCEPTOR
	enemy.scenario_state = ScenarioShipState.new()
	add_child_autofree(enemy)
	var computer: TargetingComputer = autofree(TargetingComputer.new())
	computer.targeted_enemy = enemy
	Globals.targeting_computer = computer
	var roster: EnemyManager = autofree(EnemyManager.new())
	roster.enemies = [enemy] as Array[Enemy]
	Globals.enemy_manager = roster
	Globals.tile_grid = autofree(TileGrid.new())


func after_each() -> void:
	Globals.enemy_manager = null
	super()


func _tile(tile_id: String) -> Tile:
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = load(TILES % tile_id)
	add_child_autofree(tile)
	return tile


## A die in the player's hand.
func _die(face: int) -> Dice:
	var die: Dice = DICE_SCENE.instantiate()
	die.value = face
	# Under the player node, where every die in the game lives.
	player.add_child(die)
	player.dice_manager.add(die)
	return die


## Drops [param die] on [param tile] as Tile._on_die_accepted does, without
## playing it yet.
func _place(tile: Tile, die: Dice) -> TileActivationEvent:
	tile.dice_queue.add(die, true, false)
	var event := TileActivationEvent.new()
	event.tile = tile
	event.activator_die = die
	event.die_value = die.value
	return event


## Plays a placed die's activation, then moves the dice the way the recorded
## hold and hand-off events say. Returns the events it made.
func _play(event: TileActivationEvent) -> Array[EffectEvent]:
	engine.injected.clear()
	await event.resolve(engine)
	var made: Array[EffectEvent] = engine.injected.duplicate()
	for each: EffectEvent in made:
		if each is KeepDieWithTileEvent or each is GiveDieToTargetEvent or each is GiveDieToPlayerEvent:
			await each.resolve(engine)
		# Land a die handed over at once, and let its beam go before the test
		# ends: a beam freed after its die trips over the freed die.
		if each is GiveDieToTargetEvent:
			TractorBeam.release(each.activator_die)
			await get_tree().process_frame
	return made


func _drop(tile: Tile, face: int) -> Array[EffectEvent]:
	return await _play(_place(tile, _die(face)))


func _of(events: Array[EffectEvent], script: Script) -> Array[EffectEvent]:
	return events.filter(func(e: EffectEvent) -> bool: return is_instance_of(e, script))


func _damage(events: Array[EffectEvent]) -> Array[int]:
	var out: Array[int] = []
	for event: EffectEvent in _of(events, DamageEvent):
		out.append(event.amount)
	return out


# ── The hold ─────────────────────────────────────────────────────────────────

func test_the_first_die_is_held_on_the_tile_and_deals_nothing() -> void:
	var tile: Tile = _tile("twin_barrel")
	var first: Dice = _die(4)
	var events: Array[EffectEvent] = await _play(_place(tile, first))
	assert_eq(_damage(events), [] as Array[int])
	assert_eq(tile.get_held_die(), first, "it waits on the tile, where Welder's does")
	assert_has(tile.dice_queue.queue, first)
	assert_does_not_have(player.dice_manager.queue, first)


func test_a_die_only_dropped_on_the_tile_is_not_held() -> void:
	# Two dice dropped before the first one's activation resolves: the
	# second is waiting its turn, not held, so the first doesn't pay out on it.
	var tile: Tile = _tile("twin_barrel")
	var first: Dice = _die(2)
	var second: Dice = _die(5)
	var first_drop: TileActivationEvent = _place(tile, first)
	var second_drop: TileActivationEvent = _place(tile, second)
	assert_null(tile.get_held_die(first))
	assert_eq(_damage(await _play(first_drop)), [] as Array[int], "the first is held")
	assert_eq(tile.get_held_die(second), first)
	assert_eq(_damage(await _play(second_drop)), [10], "the second pays out: 2 + 5 + 3")


func test_a_held_die_picked_back_up_is_no_longer_held() -> void:
	var tile: Tile = _tile("twin_barrel")
	var first: Dice = _die(3)
	await _play(_place(tile, first))
	player.dice_manager.add(first)
	assert_null(tile.get_held_die())
	# Dropped here again it's a fresh hold, not a pair with itself.
	tile.dice_queue.add(first, true, false)
	assert_null(tile.get_held_die(), "only a hold makes a die held")


# ── Refusals ─────────────────────────────────────────────────────────────────

func test_pairs_with_reads_matches_and_sums() -> void:
	var match_check := ActivationResource.new()
	match_check.type = ActivationResource.ActivationType.MATCHES_HELD_DIE
	assert_true(match_check.pairs_with(4, 4))
	assert_false(match_check.pairs_with(4, 3))
	var sum_check := ActivationResource.new()
	sum_check.type = ActivationResource.ActivationType.SUMS_WITH_HELD_DIE
	sum_check.threshold = 7
	assert_true(sum_check.pairs_with(6, 1))
	assert_false(sum_check.pairs_with(6, 6))


# ── Payouts ──────────────────────────────────────────────────────────────────

func test_twin_barrel_hits_for_both_dice_plus_three_and_gives_both() -> void:
	var tile: Tile = _tile("twin_barrel")
	var first: Dice = _die(4)
	await _play(_place(tile, first))
	var second: Dice = _die(6)
	var events: Array[EffectEvent] = await _play(_place(tile, second))
	assert_eq(_damage(events), [13])
	var gives: Array[EffectEvent] = _of(events, GiveDieToTargetEvent)
	assert_eq(gives.size(), 2)
	for give: EffectEvent in gives:
		assert_eq(give.targets, [enemy] as Array[Node])
	assert_has(enemy.dice_manager.queue, first)
	assert_has(enemy.dice_manager.queue, second)
	assert_null(tile.get_held_die())


func test_twin_barrel_plus_adds_six() -> void:
	var tile: Tile = _tile("twin_barrel_plus")
	await _drop(tile, 1)
	assert_eq(_damage(await _drop(tile, 2)), [9])


func test_a_repeated_payout_hits_twice_and_gives_each_die_once() -> void:
	var tile: Tile = _tile("twin_barrel")
	await _drop(tile, 2)
	var event: TileActivationEvent = _place(tile, _die(3))
	event.activation_repetitions = 2
	var events: Array[EffectEvent] = await _play(event)
	assert_eq(_damage(events), [8, 8])
	assert_eq(_of(events, GiveDieToTargetEvent).size(), 2)


# ── Echo ─────────────────────────────────────────────────────────────────────

func test_an_echo_waits_out_the_hold_for_the_payout() -> void:
	var tile: Tile = _tile("twin_barrel")
	var hold: TileActivationEvent = _place(tile, _die(2))
	assert_false(EchoModifier.can_echo(hold, engine), "a hold has nothing to repeat")
	await _play(hold)
	assert_true(EchoModifier.can_echo(_place(tile, _die(3)), engine))


# ── AutoPilot ────────────────────────────────────────────────────────────────

func test_the_forecast_credits_a_hold_with_half_the_payout_it_sets_up() -> void:
	var tile: Tile = _tile("twin_barrel")
	var first: Dice = _die(4)
	var alone: AutoPilotForecast = AutoPilotForecast.of(tile, first, enemy)
	assert_eq(alone.damage.get(enemy, 0.0), 0.0, "nothing in hand to pay it out")
	_die(5)
	var paired: AutoPilotForecast = AutoPilotForecast.of(tile, first, enemy)
	assert_almost_eq(paired.damage.get(enemy, 0.0), 6.0, 0.01, "half of 4 + 5 + 3")


func test_the_forecast_reads_the_payout_off_the_held_die() -> void:
	var tile: Tile = _tile("twin_barrel")
	await _drop(tile, 4)
	var forecast: AutoPilotForecast = AutoPilotForecast.of(tile, _die(5), enemy)
	assert_almost_eq(forecast.damage.get(enemy, 0.0), 12.0, 0.01)
	assert_eq(forecast.handoffs.size(), 2, "both dice go to the target")
