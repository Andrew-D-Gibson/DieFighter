extends "res://test/helpers/die_fighter_test.gd"
## Which permanent rule (or timed hazard) each background carries, and that
## the authored rules still do what their descriptions say once
## BackgroundModifierManager puts them on a live engine.
##
## The pairings are a design choice (each rule sits where it fits the place:
## the pulsar strips shields, shrapnel makes every hit worse), so they are
## pinned here. Change the table when the design changes, not to make the
## suite pass.

const Ships := preload("res://test/helpers/ships.gd")

const BACKGROUND_ROOT: String = "res://Source/Resources/BackgroundResources/"

## Background -> the Modifier class its rule builds (or "" for none).
const RULES: Dictionary[String, String] = {
	"blue_nebula": "AmountCapModifier",
	"cryo_belt": "DiceFreezeModifier",
	"debris_field": "DoubleDamageModifier",
	"derelict_boneyard": "OncePerTurnModifier",
	"fate_infection": "NoEscapeModifier",
	"fate_outskirt": "",
	"pulsar_field": "ShieldBlackoutModifier",
	"red_nebula": "RepairBlackoutModifier",
	"empty_space": "",
	"star_field": "",
	"asteroid_field": "",
	"ion_storm_front": "",
	"rift_space": "",
	"solar_corona": "",
}

## Backgrounds whose place is a timed hazard instead.
const HAZARDS: Dictionary[String, String] = {
	"fate_outskirt": "Fate Rift",
	"asteroid_field": "Asteroid Impact",
	"ion_storm_front": "Ion Storm",
	"rift_space": "Fate Rift",
	"solar_corona": "Solar Flare",
}


## The real manager, reading a fixed engine instead of the scenario manager's.
class TestModifierManager:
	extends BackgroundModifierManager
	var engine: ScenarioEngine

	func _get_engine() -> ScenarioEngine:
		return engine


var engine: ScenarioEngine
var manager: TestModifierManager
var ship: Player
var context: EffectContext


func before_each() -> void:
	super()
	engine = autofree(ScenarioEngine.new())
	# Kept out of the tree so it doesn't hook the real Events in _ready().
	manager = autofree(TestModifierManager.new())
	manager.engine = engine

	ship = make_player()
	var health: Health = autofree(Health.new())
	health.max_health = 20
	health.health = 10
	ship.health = health
	context = EffectContext.new()
	context.actor = ship
	context.targets = [ship]


func _arrive_at(background_name: String) -> void:
	var background_manager: BackgroundManager = autofree(BackgroundManager.new())
	background_manager.current_background = load(BACKGROUND_ROOT + background_name + ".tres")
	Globals.background_manager = background_manager
	manager._apply_current_background()


func test_each_background_carries_the_rule_that_fits_it() -> void:
	for background_name: String in RULES:
		var background: BackgroundResource = load(BACKGROUND_ROOT + background_name + ".tres")
		var expected: String = RULES[background_name]
		if expected.is_empty():
			assert_null(background.global_modifier, "%s has no rule" % background_name)
			continue
		var modifier: Modifier = background.global_modifier.create_modifier()
		assert_eq(modifier.get_script().get_global_name(), expected, background_name)


func test_hazard_backgrounds_keep_their_hazards() -> void:
	for background_name: String in HAZARDS:
		var background: BackgroundResource = load(BACKGROUND_ROOT + background_name + ".tres")
		assert_not_null(background.hazard, background_name)
		if background.hazard:
			assert_eq(background.hazard.hazard_name, HAZARDS[background_name])


func test_by_the_pulsar_no_shield_goes_up() -> void:
	_arrive_at("pulsar_field")
	assert_true(manager.get_active_modifier() is ShieldBlackoutModifier)
	await Effects.chain([Effects.set_amount(3), Effects.shield()]).play(context, engine)
	assert_eq(ship.health.shields, 0)


## The ships already in the region arrive with their shields flat, as the
## player does.
func test_by_the_pulsar_the_ships_already_there_start_bare() -> void:
	var raider: Enemy = _ship_with_shields(4)
	_arrive_at("pulsar_field")
	assert_eq(raider.health.shields, 0)


func test_elsewhere_the_ships_keep_their_shields() -> void:
	var raider: Enemy = _ship_with_shields(4)
	_arrive_at("debris_field")
	assert_eq(raider.health.shields, 4)


## A ship the scenario would raise shields on as it arrives gets none either.
func test_by_the_pulsar_an_arrival_shield_grant_is_blocked() -> void:
	var raider: Enemy = _ship_with_shields(0)
	_arrive_at("pulsar_field")
	var grant: EffectContext = EffectContext.new()
	grant.actor = raider
	grant.targets = [raider]
	await Effects.chain([Effects.set_amount(3), Effects.shield()]).play(grant, engine)
	assert_eq(raider.health.shields, 0)


## An enemy in the arriving roster, with [param shields] up.
func _ship_with_shields(shields: int) -> Enemy:
	var raider: Enemy = autofree(Ships.ship(ScenarioManager.Faction.PIRATE))
	autofree(raider.health)
	raider.health.shields = shields
	var enemy_manager: EnemyManager = autofree(EnemyManager.new())
	enemy_manager.enemies = [raider]
	Globals.enemy_manager = enemy_manager
	return raider


func test_in_the_blue_nebula_nothing_exceeds_three() -> void:
	_arrive_at("blue_nebula")
	await Effects.chain([Effects.set_amount(5), Effects.shield()]).play(context, engine)
	assert_eq(ship.health.shields, 3)


func test_in_the_red_nebula_no_hull_is_repaired() -> void:
	_arrive_at("red_nebula")
	var heal: EffectData = Effects.data(EffectEnums.Category.ATTRIBUTE_CHANGE, EffectEnums.AttributeChangeSubtype.HEAL)
	await Effects.chain([Effects.set_amount(5), heal]).play(context, engine)
	assert_eq(ship.health.health, 10)


func test_in_the_debris_field_the_rule_is_on_the_engine() -> void:
	_arrive_at("debris_field")
	assert_true(manager.get_active_modifier() is DoubleDamageModifier)
	assert_has(engine.modifiers, manager.get_active_modifier())


func test_fate_outskirt_keeps_shards_and_storm_without_black_hole() -> void:
	var infection: BackgroundResource = load(BACKGROUND_ROOT + "fate_infection.tres")
	var outskirt: BackgroundResource = load(BACKGROUND_ROOT + "fate_outskirt.tres")
	assert_not_null(outskirt)
	assert_eq(outskirt.scrolling_objects, infection.scrolling_objects, "keeps fate_shards")
	assert_gt(outskirt.num_of_stars, infection.num_of_stars, "more stars than black-hole sky")
	assert_gt(outskirt.num_of_twinkling_stars, infection.num_of_twinkling_stars, "more twinkling stars")
	var scenes: Array[String] = []
	for obj: StaticBackgroundObjectResource in outskirt.static_objects:
		if obj and obj.scene:
			scenes.append(obj.scene.resource_path.get_file())
	assert_has(scenes, "fate_storm.tscn", "keeps FateStorm lightning and shader flashes")
	assert_does_not_have(scenes, "black_hole.tscn", "no black hole outside the danger zone")


func test_doldrums_lift_after_three_complete_rounds() -> void:
	_arrive_at("blue_nebula")
	assert_eq(manager.turns_remaining, 3)
	for remaining: int in [2, 1]:
		manager._on_round_ended()
		assert_eq(manager.turns_remaining, remaining)
		assert_true(manager.get_active_modifier() is AmountCapModifier)
	manager._on_round_ended()
	assert_null(manager.get_active_modifier())
	await Effects.chain([Effects.set_amount(5), Effects.shield()]).play(context, engine)
	assert_eq(ship.health.shields, 5, "the expired cap no longer limits effects")


func test_corruption_blocks_only_combat_jumps_not_charge() -> void:
	Globals.player = ship
	var scenario_manager: ScenarioManager = autofree(ScenarioManager.new())
	scenario_manager.engine = engine
	Globals.scenario_manager = scenario_manager
	var state: GameStateManager = autofree(GameStateManager.new())
	Globals.state_manager = state
	var map: Map = autofree(Map.new())
	Globals.map = map
	state.state = GameStateManager.GameState.IN_COMBAT
	_arrive_at("fate_infection")
	assert_true(manager.get_active_modifier() is NoEscapeModifier)
	assert_false(map.can_jump())
	var charge: ChangeEngineChargeEvent = ChangeEngineChargeEvent.new()
	charge.amount = 5
	await charge.resolve(engine)
	assert_eq(ship.engine_charge, 5, "charge remains usable")
	ship.engine_charge = ship.max_engine_charge
	var full: ActivationResource = ActivationResource.new()
	full.type = ActivationResource.ActivationType.ENGINE_CHARGED
	assert_true(full.criteria_satisfied(null), "fully charged combat tiles still work")
	var jump: ActivationResource = ActivationResource.new()
	jump.type = ActivationResource.ActivationType.CAN_JUMP
	assert_false(jump.criteria_satisfied(null), "jump controls refuse before spending a die")
	state.state = GameStateManager.GameState.OUT_OF_COMBAT
	assert_true(map.can_jump(), "winning releases the ship")
	assert_eq(ActivationResource.ActivationType.PLAYER_HAS_HARMFUL_STATUS, 22)
	assert_eq(ActivationResource.ActivationType.CAN_JUMP, 23)
