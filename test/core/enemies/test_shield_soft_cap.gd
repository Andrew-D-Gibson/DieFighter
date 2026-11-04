extends "res://test/helpers/die_fighter_test.gd"
## The soft cap on enemy shields: once a ship holds as many shields as its max
## hull, actions that only shield it (Shield Burst, Aegis Link) stop being
## rolled for it. Nothing clamps the shields themselves, and actions that
## shield as a side effect (Relay, Charge Bore) are left alone.

const Ships := preload("res://test/helpers/ships.gd")
const Faction := ScenarioManager.Faction
const ACTIONS := "res://Source/Content/Enemies/EnemyActions/EnemyActionResources/"


func before_each() -> void:
	super()
	RNGManager.seed_scenario(7)


func _ship(shields: int = 0, hull: int = 10, max_hull: int = 10) -> Enemy:
	var made: Enemy = Ships.ship(Faction.PIRATE, hull, max_hull)
	made.health.shields = shields
	autofree(made.health)
	return autofree(made)


func _shipped(file: String) -> EnemyActionResource:
	return load(ACTIONS + file) as EnemyActionResource


func _option(file: String) -> EnemyActionOptionResource:
	return Ships.option(_shipped(file))


func test_only_pure_shield_actions_count() -> void:
	assert_true(_shipped("shield_self.tres").only_grants_shields(), "Shield Burst")
	assert_true(_shipped("aegis_ally.tres").only_grants_shields(), "Aegis Link")
	assert_false(_shipped("relay.tres").only_grants_shields(), "Relay passes its die on")
	assert_false(_shipped("charge_weapon.tres").only_grants_shields(), "Charge Bore loads a die")
	assert_false(_shipped("attack_player.tres").only_grants_shields())


func test_the_cap_is_the_ships_max_hull() -> void:
	assert_false(EnemyActionSituation.at_shield_cap(_ship(9, 4, 10)))
	assert_true(EnemyActionSituation.at_shield_cap(_ship(10, 4, 10)), "max hull, not hull left")
	assert_true(EnemyActionSituation.at_shield_cap(_ship(40, 10, 10)))


func test_shield_burst_stops_at_the_cap() -> void:
	var under := _ship(9)
	var at := _ship(10)
	var burst := _option("shield_self.tres")
	assert_true(EnemyActionSelector.is_available(burst, EnemyActionSituation.for_ship(under, Ships.roster([under]))))
	assert_false(EnemyActionSelector.is_available(burst, EnemyActionSituation.for_ship(at, Ships.roster([at]))))


func test_a_capped_ship_still_rolls_its_side_effect_shields() -> void:
	var capped := _ship(10)
	var bore := _option("charge_weapon.tres")
	assert_true(EnemyActionSelector.is_available(bore, EnemyActionSituation.for_ship(capped, Ships.roster([capped]))))


func test_aegis_link_needs_an_ally_under_the_cap() -> void:
	var aegis := _ship(50)
	var full := _ship(10)
	var open := _ship(3)
	var link := _option("aegis_ally.tres")
	assert_false(EnemyActionSelector.is_available(link, EnemyActionSituation.for_ship(aegis, Ships.roster([aegis, full]))),
		"its only ally is full")
	assert_true(EnemyActionSelector.is_available(link, EnemyActionSituation.for_ship(aegis, Ships.roster([aegis, full, open]))),
		"its own shields don't matter, the ally's do")


func test_a_full_table_of_shields_falls_back_to_something_else() -> void:
	var capped := _ship(10)
	var pool := Ships.pool([_option("shield_self.tres")] as Array[EnemyActionOptionResource])
	for action: EnemyActionResource in EnemyActionSelector.roll(pool, EnemyActionSituation.for_ship(capped, Ships.roster([capped]))):
		assert_false(action.only_grants_shields())


func test_aegis_link_is_bound_to_an_ally_under_the_cap() -> void:
	var aegis := _ship()
	# The full ship is the most damaged, so it would be the partner without the cap.
	var full := _ship(10, 2, 10)
	var open := _ship(0, 9, 10)
	var roster := Ships.roster([aegis, full, open])
	for run: int in range(10):
		RNGManager.seed_scenario(run)
		var table: Array[EnemyActionResource] = [_shipped("aegis_ally.tres").duplicate(true)]
		aegis.turn_actions = table
		EnemyTargetBinder.bind(Ships.roster([aegis]), roster)
		assert_eq(aegis.turn_actions[0].bound_target, open)


func test_shields_over_the_cap_are_kept() -> void:
	var ship := _ship(25)
	EnemyActionSituation.for_ship(ship, Ships.roster([ship]))
	assert_eq(ship.health.shields, 25, "a soft cap stops new shields, it takes none away")
