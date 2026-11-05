extends "res://test/helpers/die_fighter_test.gd"
## PIERCING_DAMAGE (Leeching Shot's "Steal hull"): a hit that skips the
## shields and takes the hull, while still being a hit like any other.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const Ships := preload("res://test/helpers/ships.gd")

var engine: RecordingEngine


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	Globals.state_manager = autofree(GameStateManager.new())


func test_the_hit_takes_the_hull_and_leaves_the_shields() -> void:
	var ship: Enemy = autofree(Ships.ship(ScenarioManager.Faction.PIRATE, 7, 10))
	autofree(ship.health)
	ship.health.shields = 5
	var data := Effects.data(EffectEnums.Category.ATTRIBUTE_CHANGE, EffectEnums.AttributeChangeSubtype.PIERCING_DAMAGE)
	var context := EffectContext.new()
	context.running_amount = 3
	var targets: Array[Node] = [ship]
	context.targets = targets
	await EffectRegistry.get_handler(data.category, data.subtype).apply(data, context, engine)
	assert_eq(engine.injected.size(), 1)
	var hit: DamageEvent = engine.injected[0] as DamageEvent
	assert_not_null(hit, "still a DamageEvent, so hit modifiers see it")
	hit.resolve(engine)
	assert_eq(ship.health.shields, 5)
	assert_eq(ship.health.health, 4)
