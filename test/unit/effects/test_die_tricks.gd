extends "res://test/helpers/die_fighter_test.gd"
## The die-trick tiles: Die Splitter (SPLIT_ACTIVATOR), Doubler and Nudge Down
## (ADD_TO_ACTIVATOR_VALUE stepping by the die, or down by one), played whole
## from their authored chains, plus what the AutoPilot reads off them.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const Ships := preload("res://test/helpers/ships.gd")
const TILES: String = "res://Source/Content/Tiles/TileResources/%s.tres"


## A FakeDie that lands its new face straight away instead of tweening.
class RollingDie extends "res://test/helpers/fake_die.gd":
	var holographic: bool = false

	func reroll_with_tween(new_value: int = 0, _tween_time: float = 0.2) -> void:
		value = new_value


## A Player that records the dice it is asked to spawn rather than building
## them, since it isn't in the tree.
class SpawnSpyPlayer extends Player:
	var spawned: Array[Dictionary] = []

	func spawn_dice(num_to_spawn: int = 1, value: int = 0, holographic: bool = false) -> void:
		spawned.append({"count": num_to_spawn, "value": value, "holo": holographic})


var player: SpawnSpyPlayer


func before_each() -> void:
	super()
	player = autofree(SpawnSpyPlayer.new())
	Globals.player = player


func _tile(tile_id: String) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.sprite_frames = null
	tile.tile_resource = load(TILES % tile_id)
	return tile


## An empty grid of the default rectangle, so Feeds can find a tile's cell.
func _grid() -> TileGrid:
	var grid: TileGrid = autofree(TileGrid.new())
	grid.set_cells([] as Array[Vector2i])
	Globals.tile_grid = grid
	return grid


## Plays [param tile_id]'s authored chain at (1, 1) of a 5x3 grid, with
## [param right] (if any) at (2, 1), and returns the events it produced.
func _play(tile_id: String, face: int, right: Tile = null) -> Array[EffectEvent]:
	var engine: RecordingEngine = autofree(RecordingEngine.new())
	var grid: TileGrid = _grid()
	var tile: Tile = _tile(tile_id)
	grid.tile_locations[Vector2i(1, 1)] = tile
	if right:
		grid.tile_locations[Vector2i(2, 1)] = right
	var context := EffectContext.new()
	context.effect_source = tile
	context.activator_die = autofree(RollingDie.new(face))
	await tile.tile_resource.effect_chain.play(context, engine)
	return engine.injected.duplicate()


func _of(events: Array[EffectEvent], script: Script) -> Array[EffectEvent]:
	return events.filter(func(e: EffectEvent) -> bool: return is_instance_of(e, script))


func _faces(tile_id: String) -> Array[int]:
	var resource: TileResource = load(TILES % tile_id)
	for check: ActivationResource in resource.activation_checks:
		if check.type == ActivationResource.ActivationType.VALUE:
			return check.acceptable_values
	return []


# ── Die Splitter ───────────────────────────────────────────────────────────────

func test_a_split_keeps_the_bigger_half_and_the_two_add_up() -> void:
	assert_eq(SplitActivatorEvent.halves(2), Vector2i(1, 1))
	assert_eq(SplitActivatorEvent.halves(3), Vector2i(2, 1))
	assert_eq(SplitActivatorEvent.halves(4), Vector2i(2, 2))
	assert_eq(SplitActivatorEvent.halves(5), Vector2i(3, 2))
	assert_eq(SplitActivatorEvent.halves(6), Vector2i(3, 3))
	assert_eq(SplitActivatorEvent.halves(1).y, 0, "a 1 has nothing to split off")


func test_splitting_a_five_leaves_a_three_and_a_two_hologram() -> void:
	var die: RollingDie = autofree(RollingDie.new(5))
	var event := SplitActivatorEvent.new()
	event.activator_die = die
	await event.resolve(autofree(ScenarioEngine.new()))
	assert_eq(die.value, 3)
	assert_eq(player.spawned, [{"count": 1, "value": 2, "holo": true}] as Array[Dictionary])


func test_a_one_is_left_alone() -> void:
	var die: RollingDie = autofree(RollingDie.new(1))
	var event := SplitActivatorEvent.new()
	event.activator_die = die
	await event.resolve(autofree(ScenarioEngine.new()))
	assert_eq(die.value, 1)
	assert_true(player.spawned.is_empty())


func test_a_freeze_cancels_both_halves() -> void:
	var engine: ScenarioEngine = autofree(ScenarioEngine.new())
	engine.add_modifier(DiceFreezeModifier.new())
	var die: RollingDie = autofree(RollingDie.new(6))
	var context := EffectContext.new()
	context.activator_die = die
	var split := Effects.data(EffectEnums.Category.DICE_CONTROL, EffectEnums.DiceControlSubtype.SPLIT_ACTIVATOR)
	await Effects.chain([split]).play(context, engine)
	assert_eq(die.value, 6)
	assert_true(player.spawned.is_empty(), "no free hologram while the face is frozen")


func test_die_splitter_splits_once_then_returns_the_die() -> void:
	var events: Array[EffectEvent] = await _play("die_splitter", 6)
	assert_eq(_of(events, SplitActivatorEvent).size(), 1)
	assert_eq(_of(events, GiveDieToPlayerEvent).size(), 1)
	assert_true(events.find(_of(events, SplitActivatorEvent)[0]) \
		< events.find(_of(events, GiveDieToPlayerEvent)[0]), "split, then home")


func test_die_splitter_refuses_a_one() -> void:
	assert_eq(_faces("die_splitter"), [2, 3, 4, 5, 6] as Array[int])
	assert_eq(_faces("die_splitter_plus"), [2, 3, 4, 5, 6] as Array[int])


# ── Doubler ────────────────────────────────────────────────────────────────────

func test_doubler_adds_the_die_to_itself_and_feeds_right() -> void:
	var events: Array[EffectEvent] = await _play("doubler", 3)
	var steps: Array[EffectEvent] = _of(events, AddToActivatorValueEvent)
	assert_eq(steps.size(), 1)
	assert_eq(steps[0].amount, 3, "3 + 3 = 6")
	assert_eq(_of(events, PassDieToTileEvent).size(), 1)


func test_doubler_takes_only_one_to_three() -> void:
	assert_eq(_faces("doubler"), [1, 2, 3] as Array[int])
	assert_eq(_faces("doubler_plus"), [1, 2, 3] as Array[int])


# ── Nudge Down ─────────────────────────────────────────────────────────────────

func test_nudge_down_steps_the_die_down_one_and_feeds_right() -> void:
	var events: Array[EffectEvent] = await _play("nudge_down", 4)
	var steps: Array[EffectEvent] = _of(events, AddToActivatorValueEvent)
	assert_eq(steps.size(), 1)
	assert_eq(steps[0].amount, -1)
	assert_eq(_of(events, PassDieToTileEvent).size(), 1)


func test_nudge_down_refuses_a_one() -> void:
	assert_eq(_faces("nudge_down"), [2, 3, 4, 5, 6] as Array[int])
	assert_eq(_faces("nudge_down_plus"), [2, 3, 4, 5, 6] as Array[int])


func test_a_step_down_lowers_the_face_and_an_amplifier_leaves_it_down() -> void:
	var engine: ScenarioEngine = autofree(ScenarioEngine.new())
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	engine.add_modifier(AmplifierModifier.new(tile, 2))
	var die: RollingDie = autofree(RollingDie.new(4))
	var context := EffectContext.new()
	context.effect_source = tile
	context.activator_die = die
	var add := Effects.data(EffectEnums.Category.DICE_CONTROL, EffectEnums.DiceControlSubtype.ADD_TO_ACTIVATOR_VALUE)
	await Effects.chain([Effects.set_amount(-1), add]).play(context, engine)
	assert_eq(die.value, 3, "an Amplifier's +2 doesn't turn -1 into a rise")


func test_upgrades_add_a_use() -> void:
	for pair: Array in [["die_splitter", 1, 2], ["doubler", 1, 2], ["nudge_down", 2, 3]]:
		var base: TileResource = load(TILES % pair[0])
		var plus: TileResource = load(TILES % (pair[0] + "_plus"))
		assert_eq(base.uses_per_turn, pair[1], pair[0])
		assert_eq(plus.uses_per_turn, pair[2], pair[0] + "_plus")
		assert_eq(base.upgraded_version, plus)


# ── Value Exchange, Holo-Duplicator ───────────────────────────────────────────

func test_value_exchange_flips_then_gives_the_die_to_the_target() -> void:
	var enemy: Enemy = autofree(ENEMY_SCENE.instantiate())
	var computer: TargetingComputer = autofree(TargetingComputer.new())
	computer.targeted_enemy = enemy
	Globals.targeting_computer = computer
	for tile_id: String in ["value_exchange", "value_exchange_plus"]:
		var events: Array[EffectEvent] = await _play(tile_id, 4)
		var flips: Array[EffectEvent] = _of(events, FlipOnesAndSixesEvent)
		var gives: Array[EffectEvent] = _of(events, GiveDieToTargetEvent)
		assert_eq(flips.size(), 1, tile_id)
		assert_eq(gives.size(), 1, tile_id + " pays with the die")
		assert_eq(_of(events, GiveDieToPlayerEvent).size(), 0, tile_id + " no longer returns it")
		if flips.size() == 1 and gives.size() == 1:
			assert_true(events.find(flips[0]) < events.find(gives[0]), "flip, then hand over")


func test_holo_duplicator_copies_only_a_low_die() -> void:
	assert_eq(_faces("holographic_duplicator"), [1, 2, 3] as Array[int])
	assert_eq(_faces("holographic_duplicator_plus"), [1, 2, 3] as Array[int])


# ── AutoPilot ──────────────────────────────────────────────────────────────────

func test_the_forecast_counts_the_hologram_and_the_kept_half() -> void:
	var forecast: AutoPilotForecast = AutoPilotForecast.of(_tile("die_splitter"),
		autofree(RollingDie.new(5)), null, [] as Array[Enemy])
	assert_eq(forecast.dice_back, 2.0, "the die home, and its hologram")


func test_the_forecast_follows_a_nudged_die_into_a_doubler() -> void:
	var grid: TileGrid = _grid()
	var nudge: Tile = _tile("nudge_down")
	var doubler: Tile = _tile("doubler")
	grid.tile_locations[Vector2i(1, 1)] = nudge
	grid.tile_locations[Vector2i(2, 1)] = doubler
	var ship: Enemy = autofree(Ships.ship(ScenarioManager.Faction.PIRATE, 10, 10))
	autofree(ship.health)
	var forecast: AutoPilotForecast = AutoPilotForecast.of(nudge, autofree(RollingDie.new(4)),
		ship, Ships.roster([ship]))
	assert_eq(forecast.deepest_feed, 1, "4 - 1 = 3, which the Doubler takes")
	assert_eq(forecast.handoffs.size(), 1)
	assert_eq(forecast.handoffs[0].face, 6, "3 doubled, fed off the grid to the target")
