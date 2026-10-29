extends "res://test/helpers/die_fighter_test.gd"
## Which permanent rule (or timed hazard) each background carries, and that
## the authored rules still do what their descriptions say once
## BackgroundModifierManager puts them on a live engine.
##
## The pairings are a design choice (each rule sits where it fits the place:
## the pulsar strips shields, shrapnel makes every hit worse), so they are
## pinned here. Change the table when the design changes, not to make the
## suite pass.

const BACKGROUND_ROOT: String = "res://Source/Resources/BackgroundResources/"

## Background -> the Modifier class its rule builds (or "" for none).
const RULES: Dictionary[String, String] = {
	"blue_nebula": "AmountCapModifier",
	"cryo_belt": "DiceFreezeModifier",
	"debris_field": "DoubleDamageModifier",
	"derelict_boneyard": "OncePerTurnModifier",
	"fate_infection": "EngineBlackoutModifier",
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
