extends "res://test/helpers/die_fighter_test.gd"
## The full path an effect takes: EffectChain → EffectRegistry handler →
## ScenarioEngine → modifiers by priority → event resolution → Health.
##
## Shield and heal are used rather than damage because their events touch
## nothing but the target's Health, so the whole pipeline runs for real.

const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")

var engine: ScenarioEngine
var tile: Tile
var ship: Player
var context: EffectContext


func before_each() -> void:
	super()
	engine = autofree(ScenarioEngine.new())
	tile = autofree(TILE_SCENE.instantiate())

	# A target with a Health, which is all ShieldEvent / HealEvent touch.
	ship = make_player()
	var health: Health = autofree(Health.new())
	health.max_health = 20
	health.health = 10
	ship.health = health

	context = EffectContext.new()
	context.actor = ship
	context.effect_source = tile
	context.targets = [ship]


func _play_shield(amount: int) -> void:
	await Effects.chain([Effects.set_amount(amount), Effects.shield()]).play(context, engine)


func test_a_chain_resolves_all_the_way_to_health() -> void:
	await _play_shield(3)
	assert_eq(ship.health.shields, 3)


func test_modifiers_apply_by_priority_not_by_insertion_order() -> void:
	# Add +2 (priority 20) → cap at 4 (priority 75). Registered backwards on
	# purpose: 3 + 2 = 5, capped to 4. Cap-then-add would give 5.
	engine.add_modifier(AmountCapModifier.new(4))
	engine.add_modifier(AmplifierModifier.new(tile, 2))
	await _play_shield(3)
	assert_eq(ship.health.shields, 4)


func test_the_amplifier_only_amplifies_its_own_tile() -> void:
	engine.add_modifier(AmplifierModifier.new(autofree(TILE_SCENE.instantiate()), 2))
	await _play_shield(3)
	assert_eq(ship.health.shields, 3)


func test_a_cancellation_modifier_stops_the_effect_landing() -> void:
	engine.add_modifier(ShieldBlackoutModifier.new())
	engine.add_modifier(AmplifierModifier.new(tile, 2))
	await _play_shield(3)
	assert_eq(ship.health.shields, 0)


func test_temporary_modifiers_expire_at_the_start_of_the_player_turn() -> void:
	engine.add_modifier(AmplifierModifier.new(tile, 2))
	engine.clear_temporary_modifiers()  # what player_turn_start triggers
	await _play_shield(3)
	assert_eq(ship.health.shields, 3)


func test_repair_blackout_blocks_healing_through_the_chain() -> void:
	engine.add_modifier(RepairBlackoutModifier.new())
	var heal := Effects.data(EffectEnums.Category.ATTRIBUTE_CHANGE, EffectEnums.AttributeChangeSubtype.HEAL)
	await Effects.chain([Effects.set_amount(5), heal]).play(context, engine)
	assert_eq(ship.health.health, 10)


func test_repetitions_each_pass_through_the_modifiers() -> void:
	engine.add_modifier(AmplifierModifier.new(tile, 1))
	await Effects.chain([Effects.set_amount(2), Effects.shield()], 3).play(context, engine)
	assert_eq(ship.health.shields, 9, "(2 + 1) × 3")
