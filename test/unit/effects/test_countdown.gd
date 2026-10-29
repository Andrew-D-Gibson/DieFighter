extends "res://test/helpers/die_fighter_test.gd"
## Countdown tiles (TileCountdown): dice count the tile down by their value,
## it fires its ON_COUNTDOWN_ZERO response each time it runs out and starts
## again with the extra carried over, the count lasts between turns and
## starts full each fight, and the readout and info panel show what's left.
##
## Played through a real engine, so the count, the payout and the order they
## land in are the game's own.

const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const Ships := preload("res://test/helpers/ships.gd")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const Cat := EffectEnums.Category
## The payout below bumps this counter once per firing.
const FIRED: String = "fired"

var engine: ScenarioEngine
var grid: TileGrid


func before_each() -> void:
	super()
	engine = autofree(ScenarioEngine.new())
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = engine
	Globals.scenario_manager = manager
	Globals.player = make_player()
	grid = autofree(TileGrid.new())
	Globals.tile_grid = grid


## A countdown tile from [param start] on the grid at [param pos]: a die on
## it counts it down by its value, and each payout bumps FIRED.
func _countdown_tile(start: int, pos: Vector2i = Vector2i(0, 0)) -> Tile:
	var resource := TileResource.new()
	resource.uses_per_turn = -1
	resource.countdown = start
	var count: Array[EffectData] = [
		Effects.data(Cat.TARGETING, EffectEnums.TargetingSubtype.TARGET_EFFECT_SOURCE),
		Effects.die_value(),
		Effects.data(Cat.TILE_CONTROL, EffectEnums.TileControlSubtype.COUNT_DOWN),
	]
	resource.effect_chain = Effects.chain(count)
	var bump := Effects.data(Cat.TILE_CONTROL, EffectEnums.TileControlSubtype.INCREMENT_TILE_DATA)
	bump.string_param = FIRED
	var payout: Array[EffectData] = [bump]
	var zero := TileEvent.new()
	zero.event = TileEvent.EventType.ON_COUNTDOWN_ZERO
	resource.event_responses[zero] = Effects.chain(payout)
	return _place(resource, pos)


func _place(resource: TileResource, pos: Vector2i) -> Tile:
	# The info panel shows the first frame.
	resource.textures = SpriteFrames.new()
	resource.textures.add_frame(&"default", PlaceholderTexture2D.new())
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = resource
	add_child_autofree(tile)
	grid.tile_locations[pos] = tile
	return tile


## Drops a die showing [param face] on [param tile] and lets its chain play
## out, [param times] over (an "activates twice" rule).
func _play(tile: Tile, face: int, times: int = 1) -> void:
	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = face
	var context := EffectContext.new()
	# No actor: between repetitions the chain tweens the die home on the
	# actor, and a player outside the tree would hold the drain up forever.
	context.effect_source = tile
	context.activator_die = die
	context.repetitions = times
	await tile.tile_resource.effect_chain.play(context, engine)


func _fired(tile: Tile) -> int:
	return tile.effect_data.get(FIRED, 0)


func _readout(tile: Tile) -> CountdownReadout:
	return tile.sprite_frames.get_node_or_null(^"CountdownReadout") as CountdownReadout


func test_a_countdown_starts_full_and_shows_it() -> void:
	var tile: Tile = _countdown_tile(6)
	assert_true(tile.is_countdown())
	assert_eq(tile.countdown_remaining(), 6)
	assert_not_null(_readout(tile))
	if _readout(tile):
		assert_eq(_readout(tile).value, 6)


func test_a_tile_without_one_has_no_count_and_no_readout() -> void:
	var resource := TileResource.new()
	resource.uses_per_turn = -1
	var tile: Tile = _place(resource, Vector2i(1, 0))
	assert_false(tile.is_countdown())
	assert_eq(tile.countdown_remaining(), 0)
	assert_eq(tile.count_down(5), 0)
	assert_null(_readout(tile))


func test_a_die_counts_it_down_by_its_value() -> void:
	var tile: Tile = _countdown_tile(6)
	await _play(tile, 4)
	assert_eq(tile.countdown_remaining(), 2)
	assert_eq(_fired(tile), 0, "not there yet")
	assert_eq(_readout(tile).value, 2)


func test_reaching_zero_fires_and_starts_again() -> void:
	var tile: Tile = _countdown_tile(6)
	await _play(tile, 6)
	assert_eq(_fired(tile), 1)
	assert_eq(tile.countdown_remaining(), 6)


func test_extra_counts_carry_over() -> void:
	var tile: Tile = _countdown_tile(6)
	await _play(tile, 4)
	await _play(tile, 5)
	assert_eq(_fired(tile), 1)
	assert_eq(tile.countdown_remaining(), 3, "the 3 past zero count toward the next")


func test_a_big_enough_count_runs_it_out_more_than_once() -> void:
	var tile: Tile = _countdown_tile(5)
	assert_eq(tile.count_down(12), 2)
	assert_eq(tile.countdown_remaining(), 3)


func test_activating_twice_counts_down_twice() -> void:
	var tile: Tile = _countdown_tile(6)
	await _play(tile, 4, 2)
	assert_eq(_fired(tile), 1, "4 then 4 runs a 6 out once")
	assert_eq(tile.countdown_remaining(), 4)


func test_the_payout_lands_before_the_rest_of_the_chain() -> void:
	var tile: Tile = _countdown_tile(3)
	# A step after the count stands in for the die's hand-off.
	var rest := Effects.data(Cat.TILE_CONTROL, EffectEnums.TileControlSubtype.SET_TILE_DATA)
	rest.string_param = "rest"
	tile.tile_resource.effect_chain.effects.append(rest)
	var order: Array[String] = []
	engine.event_resolved.connect(func(event: EffectEvent) -> void:
		if event is IncrementTileDataEvent:
			order.append("payout")
		elif event is SetTileDataEvent:
			order.append("rest")
	)
	await _play(tile, 3)
	assert_eq(order, ["payout", "rest"] as Array[String])


func test_the_count_lasts_between_turns() -> void:
	var tile: Tile = _countdown_tile(6)
	await _play(tile, 2)
	Events.player_turn_refresh.emit()
	assert_eq(tile.countdown_remaining(), 4)


func test_every_fight_starts_it_full() -> void:
	var tile: Tile = _countdown_tile(6)
	await _play(tile, 2)
	Events.start_combat.emit()
	assert_eq(tile.countdown_remaining(), 6)
	assert_eq(_readout(tile).value, 6)


func test_a_finished_fight_leaves_nothing_stale_to_save() -> void:
	var tile: Tile = _countdown_tile(6)
	await _play(tile, 2)
	Events.combat_finished.emit()
	assert_false(tile.effect_data.has(TileCountdown.KEY))


func test_an_upgrade_to_a_shorter_count_holds_it_inside_the_new_one() -> void:
	var tile: Tile = _countdown_tile(18)
	await _play(tile, 2)
	var shorter: TileResource = tile.tile_resource.duplicate()
	shorter.countdown = 12
	tile.tile_resource = shorter
	assert_eq(tile.countdown_remaining(), 12)
	assert_eq(_readout(tile).value, 12)


func test_the_info_panel_says_what_is_left() -> void:
	var tile: Tile = _countdown_tile(6)
	await _play(tile, 2)
	var info: InfoResource = tile._get_tile_info()
	assert_string_contains(info.bottom_label_text, "4")
	assert_string_contains(info.bottom_label_text, "(countdown)")


func test_others_are_every_other_countdown_tile() -> void:
	var cutter := TileResource.new()
	cutter.uses_per_turn = 1
	var source: Tile = _place(cutter, Vector2i(0, 0))
	var first: Tile = _countdown_tile(6, Vector2i(1, 0))
	var second: Tile = _countdown_tile(10, Vector2i(2, 0))
	var plain := TileResource.new()
	plain.uses_per_turn = -1
	_place(plain, Vector2i(0, 1))
	var others: Array[Tile] = TileCountdown.others_on_grid(source)
	assert_eq(others.size(), 2)
	assert_true(first in others and second in others)
	assert_false(first in TileCountdown.others_on_grid(first), "never itself")


func test_counting_down_the_others_fires_each_that_runs_out() -> void:
	var cutter := TileResource.new()
	cutter.uses_per_turn = 1
	var count: Array[EffectData] = [
		Effects.data(Cat.TARGETING, EffectEnums.TargetingSubtype.TARGET_OTHER_COUNTDOWN_TILES),
		Effects.die_value(),
		Effects.data(Cat.TILE_CONTROL, EffectEnums.TileControlSubtype.COUNT_DOWN),
	]
	cutter.effect_chain = Effects.chain(count)
	var source: Tile = _place(cutter, Vector2i(0, 0))
	var near: Tile = _countdown_tile(5, Vector2i(1, 0))
	var far: Tile = _countdown_tile(12, Vector2i(2, 0))
	await _play(source, 5)
	assert_eq(_fired(near), 1)
	assert_eq(near.countdown_remaining(), 5)
	assert_eq(_fired(far), 0)
	assert_eq(far.countdown_remaining(), 7)


func test_working_the_others_needs_another_countdown_on_the_grid() -> void:
	var check := ActivationResource.new()
	check.type = ActivationResource.ActivationType.OTHER_COUNTDOWN_ON_GRID
	var cutter := TileResource.new()
	cutter.uses_per_turn = 1
	cutter.activation_checks = [check] as Array[ActivationResource]
	var source: Tile = _place(cutter, Vector2i(0, 0))
	assert_eq(source.activation_refusal(null), "NO OTHER COUNTDOWNS")
	_countdown_tile(6, Vector2i(1, 0))
	assert_eq(source.activation_refusal(null), "")


## A countdown tile whose payout deals [param hit] damage to the target.
func _cannon(start: int, hit: int) -> Tile:
	var tile: Tile = _countdown_tile(start)
	var payout: Array[EffectData] = [
		Effects.data(Cat.TARGETING, EffectEnums.TargetingSubtype.TARGET_WITH_TARGETING_COMPUTER),
		Effects.set_amount(hit), Effects.damage(),
	]
	var zero: TileEvent = tile.tile_resource.event_responses.keys()[0]
	tile.tile_resource.event_responses[zero] = Effects.chain(payout)
	return tile


func _forecast_damage(tile: Tile, face: int) -> float:
	var ship: Enemy = autofree(Ships.ship(ScenarioManager.Faction.PIRATE))
	autofree(ship.health)
	var forecast := AutoPilotForecast.of(tile, autofree(FakeDie.new(face)), ship, Ships.roster([ship]))
	return forecast.damage.get(ship, 0.0)


func test_the_forecast_counts_a_payout_the_die_sets_off_in_full() -> void:
	assert_almost_eq(_forecast_damage(_cannon(6, 8), 6), 8.0, 0.001)


func test_the_forecast_values_progress_toward_the_payout() -> void:
	# Half the count, valued at half: a quarter of the payout.
	assert_almost_eq(_forecast_damage(_cannon(6, 8), 3), 2.0, 0.001)


func test_the_forecast_reads_what_is_left_not_the_full_count() -> void:
	var tile: Tile = _cannon(6, 8)
	tile.count_down(4)
	# 2 left: a 3 fires it and leaves 1 of the next 6 done.
	assert_almost_eq(_forecast_damage(tile, 3), 8.0 + 8.0 * 0.5 / 6.0, 0.001)
