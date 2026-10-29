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


# ── Capacitor Bank ───────────────────────────────────────────────────────

func test_capacitor_bank_gains_fifteen_shields_at_zero() -> void:
	var tile: Tile = _tile("capacitor_bank")
	assert_eq(tile.countdown_remaining(), 12)
	_wind_to_one(tile)
	var events: Array[EffectEvent] = await _drop(tile, 3)
	assert_eq(_amounts(events, ShieldEvent), [15])
	var shields: Array[EffectEvent] = _of(events, ShieldEvent)
	if shields.size() == 1:
		assert_eq(shields[0].targets, [Globals.player] as Array[Node], "for the player")
	assert_eq(tile.countdown_remaining(), 10, "the 2 past zero carry over")
	_gives_die_to_target(events)


func test_capacitor_bank_plus_counts_from_ten() -> void:
	var tile: Tile = _tile("capacitor_bank_plus")
	assert_eq(tile.countdown_remaining(), 10)
	_wind_to_one(tile)
	assert_eq(_amounts(await _drop(tile, 1), ShieldEvent), [15])


# ── Fuse Cutter ──────────────────────────────────────────────────────────

func test_fuse_cutter_counts_down_every_other_countdown_by_die() -> void:
	var cutter: Tile = _tile("fuse_cutter")
	var repeater: Tile = _tile("pulse_repeater", Vector2i(1, 0))
	var cannon: Tile = _tile("countdown_cannon", Vector2i(2, 0))
	_tile("damage", Vector2i(0, 1))
	var events: Array[EffectEvent] = await _drop(cutter, 6)
	assert_eq(_amounts(events, DamageEvent), [7], "the repeater runs out, the cannon doesn't")
	assert_eq(repeater.countdown_remaining(), 6)
	assert_eq(cannon.countdown_remaining(), 12)
	_gives_die_to_target(events)


func test_fuse_cutter_plus_adds_two() -> void:
	var cutter: Tile = _tile("fuse_cutter_plus")
	var cannon: Tile = _tile("countdown_cannon", Vector2i(1, 0))
	await _drop(cutter, 4)
	assert_eq(cannon.countdown_remaining(), 12)


func test_fuse_cutter_refuses_a_die_without_another_countdown() -> void:
	var cutter: Tile = _tile("fuse_cutter")
	var needs_others: ActivationResource = null
	for check: ActivationResource in cutter.tile_resource.activation_checks:
		if check.type == ActivationResource.ActivationType.OTHER_COUNTDOWN_ON_GRID:
			needs_others = check
	assert_not_null(needs_others, "it checks for other countdowns")
	if needs_others == null:
		return
	_tile("damage", Vector2i(1, 0))
	assert_false(needs_others.criteria_satisfied(null, cutter), "a plain tile doesn't count")
	_tile("capacitor_bank", Vector2i(2, 0))
	assert_true(needs_others.criteria_satisfied(null, cutter))


func test_fuse_cutter_has_one_use() -> void:
	var cutter: Tile = _tile("fuse_cutter")
	assert_eq(cutter.tile_resource.uses_per_turn, 1)
	assert_eq(cutter.tile_resource.textures.get_frame_count(&"default"), 2)


# ── Fuse Payload ─────────────────────────────────────────────────────────

func test_fuse_payload_burns_and_jams_the_target_at_zero() -> void:
	var tile: Tile = _tile("fuse_payload")
	assert_eq(tile.countdown_remaining(), 10)
	_wind_to_one(tile)
	var events: Array[EffectEvent] = await _drop(tile, 2)
	var applied: Dictionary = {}
	for event: EffectEvent in _of(events, ApplyStatusEvent):
		assert_eq(event.targets, [enemy] as Array[Node])
		applied[(event as ApplyStatusEvent).status_id] = event.amount
	assert_eq(applied, {&"burn": 4, &"jammed": 1})
	assert_eq(_of(events, DamageEvent).size(), 0, "no hit of its own")
	_gives_die_to_target(events)


func test_fuse_payload_plus_counts_from_eight() -> void:
	var tile: Tile = _tile("fuse_payload_plus")
	assert_eq(tile.countdown_remaining(), 8)


# ── Fabricator ───────────────────────────────────────────────────────────

func test_fabricator_spawns_two_sixes_at_zero() -> void:
	var tile: Tile = _tile("fabricator")
	assert_eq(tile.countdown_remaining(), 12)
	_wind_to_one(tile)
	var events: Array[EffectEvent] = await _drop(tile, 1)
	assert_eq(_amounts(events, SpawnHolographicDieEvent), [6, 6])
	_gives_die_to_target(events)


func test_fabricator_refuses_holograms_so_it_cant_feed_itself() -> void:
	var tile: Tile = _tile("fabricator")
	var hologram: Dice = autofree(DICE_SCENE.instantiate())
	hologram.value = 6
	hologram.holographic = true
	var refuses: bool = false
	for check: ActivationResource in tile.tile_resource.activation_checks:
		if check.type == ActivationResource.ActivationType.ACTIVATOR_DIE_NOT_HOLOGRAPHIC:
			refuses = not check.criteria_satisfied(hologram, tile)
	assert_true(refuses)


func test_fabricator_plus_counts_from_ten() -> void:
	var tile: Tile = _tile("fabricator_plus")
	assert_eq(tile.countdown_remaining(), 10)
