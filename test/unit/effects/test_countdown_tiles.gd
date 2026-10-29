extends "res://test/helpers/die_fighter_test.gd"
## The countdown family, played whole: the die counts the tile down and goes
## to the target, and when the count runs out the payout does what the text
## says. The engine records instead of resolving; the count-downs are
## resolved by hand, which is what sets the payouts off, and each payout's
## chain is then played the same way.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const TILES: String = "res://Source/Content/Tiles/TileResources/%s.tres"

var engine: RecordingEngine
var enemy: Enemy
var grid: TileGrid


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = engine
	Globals.scenario_manager = manager
	Globals.player = make_player()
	enemy = autofree(ENEMY_SCENE.instantiate())
	enemy.scenario_state = ScenarioShipState.new()
	var computer: TargetingComputer = autofree(TargetingComputer.new())
	computer.targeted_enemy = enemy
	Globals.targeting_computer = computer
	var roster: EnemyManager = autofree(EnemyManager.new())
	roster.enemies = [enemy] as Array[Enemy]
	Globals.enemy_manager = roster
	grid = autofree(TileGrid.new())
	Globals.tile_grid = grid


func after_each() -> void:
	Globals.enemy_manager = null
	super()


func _tile(tile_id: String, pos: Vector2i = Vector2i(0, 0)) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.tile_resource = load(TILES % tile_id)
	grid.tile_locations[pos] = tile
	return tile


## Drops a die showing [param face] on [param tile] and plays out everything
## it sets off. Returns every event, in the order they were made.
func _drop(tile: Tile, face: int) -> Array[EffectEvent]:
	engine.injected.clear()
	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = face
	var context := EffectContext.new()
	context.effect_source = tile
	context.activator_die = die
	await tile.tile_resource.effect_chain.play(context, engine)
	var i: int = 0
	while i < engine.injected.size():
		var event: EffectEvent = engine.injected[i]
		if event is CountDownEvent:
			event.resolve(engine)
		elif event is TileEventTriggeredEvent:
			var payout := EffectContext.new()
			payout.effect_source = event.responder
			await event.chain.play(payout, engine)
		i += 1
	return engine.injected.duplicate()


func _of(events: Array[EffectEvent], script: Script) -> Array[EffectEvent]:
	return events.filter(func(e: EffectEvent) -> bool: return is_instance_of(e, script))


func _amounts(events: Array[EffectEvent], script: Script) -> Array[int]:
	var out: Array[int] = []
	for event: EffectEvent in _of(events, script):
		out.append(event.amount)
	return out


func _gives_die_to_target(events: Array[EffectEvent]) -> void:
	var gives: Array[EffectEvent] = _of(events, GiveDieToTargetEvent)
	assert_eq(gives.size(), 1, "the die goes on")
	if gives.size() == 1:
		assert_eq(gives[0].targets, [enemy] as Array[Node], "to the target")


## Counts [param tile] down to 1 left without setting it off.
func _wind_to_one(tile: Tile) -> void:
	tile.count_down(tile.countdown_remaining() - 1)


# ── Pulse Repeater ───────────────────────────────────────────────────────

func test_pulse_repeater_counts_a_low_die_down_and_hands_it_on() -> void:
	var tile: Tile = _tile("pulse_repeater")
	assert_eq(tile.countdown_remaining(), 6)
	var events: Array[EffectEvent] = await _drop(tile, 4)
	assert_eq(_amounts(events, DamageEvent), [] as Array[int], "not there yet")
	assert_eq(tile.countdown_remaining(), 2)
	_gives_die_to_target(events)


func test_pulse_repeater_fires_seven_damage_at_the_target_at_zero() -> void:
	var tile: Tile = _tile("pulse_repeater")
	var events: Array[EffectEvent] = await _drop(tile, 6)
	assert_eq(_amounts(events, DamageEvent), [7])
	var hits: Array[EffectEvent] = _of(events, DamageEvent)
	if hits.size() == 1:
		assert_eq(hits[0].targets, [enemy] as Array[Node])
	assert_eq(tile.countdown_remaining(), 6)
	_gives_die_to_target(events)


func test_pulse_repeater_carries_the_extra_over() -> void:
	var tile: Tile = _tile("pulse_repeater")
	await _drop(tile, 5)
	var events: Array[EffectEvent] = await _drop(tile, 4)
	assert_eq(_amounts(events, DamageEvent), [7])
	assert_eq(tile.countdown_remaining(), 3)


func test_pulse_repeater_plus_counts_from_five() -> void:
	var tile: Tile = _tile("pulse_repeater_plus")
	assert_eq(tile.countdown_remaining(), 5)
	assert_eq(_amounts(await _drop(tile, 5), DamageEvent), [7])


# ── Countdown Cannon ─────────────────────────────────────────────────────

func test_countdown_cannon_waits_out_eighteen_then_deals_twenty_five() -> void:
	var tile: Tile = _tile("countdown_cannon")
	for face: int in [6, 6, 5]:
		assert_eq(_amounts(await _drop(tile, face), DamageEvent), [] as Array[int])
	assert_eq(tile.countdown_remaining(), 1)
	var events: Array[EffectEvent] = await _drop(tile, 1)
	assert_eq(_amounts(events, DamageEvent), [25])
	assert_eq(tile.countdown_remaining(), 18, "and starts again")
	_gives_die_to_target(events)


func test_countdown_cannon_plus_counts_from_fifteen() -> void:
	var tile: Tile = _tile("countdown_cannon_plus")
	assert_eq(tile.countdown_remaining(), 15)
	_wind_to_one(tile)
	assert_eq(_amounts(await _drop(tile, 1), DamageEvent), [25])
