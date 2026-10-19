extends "res://test/helpers/die_fighter_test.gd"
## The smart AutoPilot's reading of the board: what a tile would do with a die
## (AutoPilotForecast) and what the die costs once a ship has it
## (AutoPilotThreat).

const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const Ships := preload("res://test/helpers/ships.gd")
const Cat := EffectEnums.Category
const Targeting := EffectEnums.TargetingSubtype
const DiceControl := EffectEnums.DiceControlSubtype


func _tile(effects: Array[EffectData], repetitions: int = 1) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	var resource := TileResource.new()
	resource.effect_chain = Effects.chain(effects, repetitions)
	tile.tile_resource = resource
	return tile


func _ship(hull: int = 10) -> Enemy:
	var ship: Enemy = autofree(Ships.ship(ScenarioManager.Faction.PIRATE, hull, hull))
	autofree(ship.health)
	return ship


func _die(face: int) -> Node:
	return autofree(FakeDie.new(face))


func _targeted() -> EffectData:
	return Effects.data(Cat.TARGETING, Targeting.TARGET_WITH_TARGETING_COMPUTER)


func _give() -> EffectData:
	return Effects.data(Cat.DICE_CONTROL, DiceControl.GIVE_DIE_TO_TARGET)


## Dice Cannon: damage equal to the die, then the die goes to the target.
func _cannon() -> Tile:
	var effects: Array[EffectData] = [_targeted(), Effects.die_value(), Effects.damage(), _give()]
	return _tile(effects)


func test_a_cannon_hits_the_target_and_hands_it_the_die() -> void:
	var ship: Enemy = _ship()
	var forecast: AutoPilotForecast = AutoPilotForecast.of(_cannon(), _die(5), ship, Ships.roster([ship]))
	assert_eq(forecast.damage.get(ship, 0.0), 5.0)
	assert_eq(forecast.handoffs.size(), 1)
	assert_eq(forecast.handoffs[0].ship, ship)
	assert_eq(forecast.handoffs[0].face, 5)


func test_the_target_is_whichever_ship_is_asked_about() -> void:
	var first: Enemy = _ship()
	var second: Enemy = _ship()
	var forecast: AutoPilotForecast = AutoPilotForecast.of(_cannon(), _die(3), second,
		Ships.roster([first, second]))
	assert_false(forecast.damage.has(first))
	assert_eq(forecast.damage.get(second, 0.0), 3.0)


func test_with_nobody_targeted_the_die_comes_home() -> void:
	var forecast: AutoPilotForecast = AutoPilotForecast.of(_cannon(), _die(4), null)
	assert_eq(forecast.handoffs.size(), 0)
	assert_eq(forecast.dice_back, 1.0)


func test_a_random_target_is_spread_rather_than_drawn() -> void:
	var first: Enemy = _ship()
	var second: Enemy = _ship()
	var effects: Array[EffectData] = [
		Effects.data(Cat.TARGETING, Targeting.TARGET_RANDOM_ENEMY),
		Effects.set_amount(6), Effects.damage(), _give(),
	]
	var forecast: AutoPilotForecast = AutoPilotForecast.of(_tile(effects), _die(2), first,
		Ships.roster([first, second]))
	assert_eq(forecast.damage.get(first, 0.0), 3.0)
	assert_eq(forecast.damage.get(second, 0.0), 3.0)
	assert_null(forecast.handoffs[0].ship, "a random ship gets the die")


func test_repetitions_multiply_the_hit_but_hand_the_die_over_once() -> void:
	var ship: Enemy = _ship()
	var effects: Array[EffectData] = [_targeted(), Effects.set_amount(2), Effects.damage(), _give()]
	var forecast: AutoPilotForecast = AutoPilotForecast.of(_tile(effects, 3), _die(1), ship,
		Ships.roster([ship]))
	assert_eq(forecast.damage.get(ship, 0.0), 6.0)
	assert_eq(forecast.handoffs.size(), 1)


func test_a_raised_face_is_what_the_ship_gets_but_not_what_the_chain_reads() -> void:
	# The face changes when the queued event resolves, after the chain has
	# read the die for its damage.
	var ship: Enemy = _ship()
	var effects: Array[EffectData] = [
		Effects.set_amount(2), Effects.data(Cat.DICE_CONTROL, DiceControl.ADD_TO_ACTIVATOR_VALUE),
		_targeted(), Effects.die_value(), Effects.damage(), _give(),
	]
	var forecast: AutoPilotForecast = AutoPilotForecast.of(_tile(effects), _die(3), ship,
		Ships.roster([ship]))
	assert_eq(forecast.damage.get(ship, 0.0), 3.0)
	assert_eq(forecast.handoffs[0].face, 5)


func test_a_rerolled_die_lands_on_an_unknown_face() -> void:
	var ship: Enemy = _ship()
	var effects: Array[EffectData] = [
		Effects.data(Cat.DICE_CONTROL, DiceControl.REROLL_ACTIVATOR), _targeted(), _give(),
	]
	var forecast: AutoPilotForecast = AutoPilotForecast.of(_tile(effects), _die(6), ship,
		Ships.roster([ship]))
	assert_eq(forecast.handoffs[0].face, 0)


func test_a_condition_on_the_face_picks_its_branch() -> void:
	var ship: Enemy = _ship()
	var odd: Array[EffectData] = [Effects.set_amount(7), Effects.damage()]
	var even: Array[EffectData] = [Effects.set_amount(1), Effects.damage()]
	var effects: Array[EffectData] = [
		_targeted(), Effects.conditional(EffectEnums.ConditionalSubtype.IF_ACTIVATOR_ODD, odd, even),
	]
	var tile: Tile = _tile(effects)
	var roster: Array[Enemy] = Ships.roster([ship])
	assert_eq(AutoPilotForecast.of(tile, _die(3), ship, roster).damage.get(ship, 0.0), 7.0)
	assert_eq(AutoPilotForecast.of(tile, _die(4), ship, roster).damage.get(ship, 0.0), 1.0)


func test_keeping_the_die_hands_nothing_over() -> void:
	var ship: Enemy = _ship()
	var effects: Array[EffectData] = [Effects.data(Cat.DICE_CONTROL, DiceControl.KEEP_DIE_WITH_TILE), _give()]
	var forecast: AutoPilotForecast = AutoPilotForecast.of(_tile(effects), _die(2), ship,
		Ships.roster([ship]))
	assert_eq(forecast.handoffs.size(), 0)
	assert_eq(forecast.dice_back, 0.0)


func test_shielding_the_player_counts_as_shields() -> void:
	Globals.player = make_player()
	var effects: Array[EffectData] = [
		Effects.data(Cat.TARGETING, Targeting.TARGET_PLAYER), Effects.set_amount(8), Effects.shield(),
	]
	var forecast: AutoPilotForecast = AutoPilotForecast.of(_tile(effects), _die(3), null)
	assert_eq(forecast.shields, 8.0)


func test_a_forecast_changes_nothing() -> void:
	var ship: Enemy = _ship()
	var die: Node = _die(3)
	var effects: Array[EffectData] = [
		Effects.set_amount(6), Effects.data(Cat.DICE_CONTROL, DiceControl.CHANGE_ACTIVATOR_VALUE),
		_targeted(), Effects.die_value(), Effects.damage(), _give(),
	]
	AutoPilotForecast.of(_tile(effects), die, ship, Ships.roster([ship]))
	assert_eq(die.value, 3)
	assert_eq(ship.health.health, 10)


# ── What a die costs ───────────────────────────────────────────────────────────

func _attack(amount: int) -> EnemyActionResource:
	var attack: EnemyActionResource = Ships.attack()
	attack.intent_amount = amount
	return attack


func _idle() -> EnemyActionResource:
	var empty: Array[EffectData] = []
	return Ships.action("Idle", empty)


func _table(ship: Enemy, actions: Array[EnemyActionResource]) -> void:
	Ships.set_table(ship, actions)


func test_an_attack_face_costs_its_damage() -> void:
	var ship: Enemy = _ship()
	_table(ship, [_idle(), _attack(4), _idle(), _idle(), _idle(), _idle()])
	assert_eq(AutoPilotThreat.of_face(ship, 2), 4.0)
	assert_eq(AutoPilotThreat.of_face(ship, 1), 0.0, "a dead face")


func test_an_attack_with_no_amount_hits_for_the_face() -> void:
	var ship: Enemy = _ship()
	_table(ship, [_idle(), _idle(), _idle(), _idle(), _attack(0), _idle()])
	assert_eq(AutoPilotThreat.of_face(ship, 5), 5.0)


func test_an_unknown_face_costs_the_average() -> void:
	var ship: Enemy = _ship()
	_table(ship, [_attack(6), _idle(), _idle(), _idle(), _idle(), _idle()])
	assert_eq(AutoPilotThreat.of_face(ship, 0), 1.0)


func test_a_relay_costs_what_the_ally_does_with_the_die() -> void:
	var relayer: Enemy = _ship()
	var ally: Enemy = _ship()
	var relay: EnemyActionResource = Ships.relay()
	relay.bound_target = ally
	_table(relayer, [_idle(), _idle(), relay, _idle(), _idle(), _idle()])
	_table(ally, [_idle(), _idle(), _attack(5), _idle(), _idle(), _idle()])
	var cost: float = AutoPilotThreat.of_face(relayer, 3)
	assert_almost_eq(cost, AutoPilotThreat.NEUTRAL_FLOOR + 5.0, 0.001,
		"the relay's own shield, then the ally's attack")
