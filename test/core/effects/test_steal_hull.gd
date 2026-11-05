extends "res://test/helpers/die_fighter_test.gd"
## STEAL_HULL (Leeching Shot): a hit that skips the shields and takes the
## hull, then heals whoever fired it by the hull it took, and no more.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const Ships := preload("res://test/helpers/ships.gd")

var engine: RecordingEngine


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	Globals.state_manager = autofree(GameStateManager.new())


## Steals [param amount] from a ship with [param hull] hull and 5 shields,
## and returns the ship, with the events the steal made in engine.injected.
func _steal(amount: int, hull: int) -> Enemy:
	var ship: Enemy = autofree(Ships.ship(ScenarioManager.Faction.PIRATE, hull, 10))
	autofree(ship.health)
	ship.health.shields = 5
	var data := Effects.data(EffectEnums.Category.ATTRIBUTE_CHANGE, EffectEnums.AttributeChangeSubtype.STEAL_HULL)
	var context := EffectContext.new()
	context.actor = make_player()
	context.running_amount = amount
	var targets: Array[Node] = [ship]
	context.targets = targets
	await EffectRegistry.get_handler(data.category, data.subtype).apply(data, context, engine)
	var hit: DamageEvent = engine.injected[0] as DamageEvent
	assert_not_null(hit, "still a DamageEvent, so hit modifiers see it")
	hit.resolve(engine)
	return ship


func _healed() -> Array[int]:
	var amounts: Array[int] = []
	for event: EffectEvent in engine.injected:
		if event is HealEvent:
			amounts.append(event.amount)
	return amounts


func test_the_hull_goes_and_the_shields_stay() -> void:
	var ship: Enemy = await _steal(3, 7)
	assert_eq(ship.health.shields, 5)
	assert_eq(ship.health.health, 4)
	assert_eq(_healed(), [3] as Array[int])


func test_a_ship_can_only_give_up_the_hull_it_has() -> void:
	var ship: Enemy = await _steal(3, 2)
	assert_eq(ship.health.health, 0)
	assert_eq(_healed(), [2] as Array[int])
