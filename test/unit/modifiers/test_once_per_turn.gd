extends "res://test/helpers/die_fighter_test.gd"
## Dead Systems (OncePerTurnModifier): every grid tile activates at most once
## a turn, limited or not, and the engine is immune. The cap is read into the
## tile's own use budget, so its lights, gray-out and refusal show it.

const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const REROLL_TILE: TileResource = preload("res://Source/Content/Tiles/TileResources/reroll.tres")
const DAMAGE_TILE: TileResource = preload("res://Source/Content/Tiles/TileResources/damage.tres")
const ENGINE_CHARGER: TileResource = preload("res://Source/Content/Tiles/MapTileResources/engine_charger.tres")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const DEAD_SYSTEMS: String = "res://Source/Resources/BackgroundResources/BackgroundModifiers/dead_systems.tres"

var engine: ScenarioEngine
var rule: Modifier
## Two uses of its own.
var limited: Tile
## No limit of its own.
var unlimited: Tile
## Off the grid, like the real Engine Charger.
var charger: Tile


func before_each() -> void:
	super()
	engine = autofree(ScenarioEngine.new())
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = engine
	Globals.scenario_manager = manager
	rule = (load(DEAD_SYSTEMS) as BackgroundModifierResource).create_modifier()

	limited = _tile(REROLL_TILE)
	unlimited = _tile(DAMAGE_TILE)
	charger = _tile(ENGINE_CHARGER)
	var grid: TileGrid = autofree(TileGrid.new())
	grid.tile_locations[Vector2i(0, 0)] = limited
	grid.tile_locations[Vector2i(1, 0)] = unlimited
	Globals.tile_grid = grid


func _tile(resource: TileResource) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.tile_resource = resource
	return tile


func _die() -> Dice:
	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = 3
	return die


## What a TileActivationEvent spends.
func _spend(tile: Tile) -> void:
	if tile.uses_remaining != -1:
		tile.uses_remaining -= 1


func test_dead_systems_builds_the_once_per_turn_rule() -> void:
	assert_true(rule is OncePerTurnModifier)


func test_without_the_rule_tiles_keep_their_own_budgets() -> void:
	assert_eq(limited.uses_remaining, 2)
	assert_eq(unlimited.uses_remaining, -1)


func test_every_grid_tile_gets_one_use_the_moment_it_arrives() -> void:
	engine.add_modifier(rule)
	assert_eq(limited.uses_remaining, 1)
	assert_eq(unlimited.uses_remaining, 1)
	assert_eq(charger.max_uses_per_turn(), -1, "the engine is immune")


func test_the_lights_show_the_one_use() -> void:
	engine.add_modifier(rule)
	assert_eq(limited.sprite_frames.frame, 1, "one of its two lights lit")
	assert_eq(unlimited.sprite_frames.frame, 0, "a tile with no lights stays on its only frame")


func test_a_second_activation_is_refused_until_the_turn_refills() -> void:
	engine.add_modifier(rule)
	for tile: Tile in [limited, unlimited]:
		assert_ne(tile.activation_refusal(_die()), "NO USES REMAINING")
		_spend(tile)
		assert_eq(tile.uses_remaining, 0)
		assert_eq(tile.activation_refusal(_die()), "NO USES REMAINING")
		tile.reset_uses_remaining()
		assert_eq(tile.uses_remaining, 1, "the next turn's refill is capped too")


func test_the_engine_takes_every_die_it_is_given() -> void:
	engine.add_modifier(rule)
	charger.reset_uses_remaining()
	assert_eq(charger.uses_remaining, -1)
	_spend(charger)
	assert_ne(charger.activation_refusal(_die()), "NO USES REMAINING")


func test_lifting_the_rule_gives_unlimited_tiles_their_freedom_back() -> void:
	engine.add_modifier(rule)
	engine.remove_modifier(rule)
	assert_eq(unlimited.uses_remaining, -1)
	assert_eq(limited.uses_remaining, 1, "a budget of its own keeps what was left")


func test_repetitions_are_held_to_one_on_grid_tiles_only() -> void:
	engine.add_modifier(rule)
	var on_grid := TileActivationEvent.new()
	on_grid.tile = unlimited
	on_grid.activation_repetitions = 2
	var on_engine := TileActivationEvent.new()
	on_engine.tile = charger
	on_engine.activation_repetitions = 2
	rule.on_before_event(on_grid, engine)
	rule.on_before_event(on_engine, engine)
	assert_eq(on_grid.activation_repetitions, 1)
	assert_eq(on_engine.activation_repetitions, 2)


func test_a_use_given_back_is_refused() -> void:
	engine.add_modifier(rule)
	var refund := AddUsesRemainingEvent.new()
	refund.amount = 1
	refund.targets = [limited] as Array[Node]
	watch_signals(Events)
	rule.on_before_event(refund, engine)
	assert_true(refund.canceled)
	assert_signal_emitted_with_parameters(Events, "modifier_triggered", [rule])


func test_a_drain_still_lands() -> void:
	engine.add_modifier(rule)
	var drain := AddUsesRemainingEvent.new()
	drain.amount = -1
	drain.targets = [limited] as Array[Node]
	rule.on_before_event(drain, engine)
	assert_false(drain.canceled)


func test_the_tile_info_says_why() -> void:
	engine.add_modifier(rule)
	assert_string_contains(unlimited._get_tile_info().bottom_label_text, "Dead Systems")
	assert_false(charger._get_tile_info().bottom_label_text.contains("Dead Systems"))
