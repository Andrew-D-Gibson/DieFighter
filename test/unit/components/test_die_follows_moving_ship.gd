extends "res://test/helpers/die_fighter_test.gd"
## A ship spending a die carries it out in front of wherever the ship is now,
## not where it stood when the die left: survivors slide across the formation
## when a ship dies, often just as their own turn starts.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const COMPUTER_SCENE: PackedScene = preload("res://Source/Systems/Game/TargetingComputer/targeting_computer.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const INTERCEPTOR: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/interceptor.tres")

## Where the die waits, relative to the ship. Mirrors EnemyActionEvent.
const FRONT_OF_SHIP: Vector2 = Vector2(0, 12)

var player: Player
var ship: Enemy
var die: Dice


func before_each() -> void:
	super()
	player = add_child_autofree(PLAYER_SCENE.instantiate())
	Globals.targeting_computer = add_child_autofree(COMPUTER_SCENE.instantiate())
	ship = ENEMY_SCENE.instantiate()
	ship.enemy_resource = INTERCEPTOR
	var state: ScenarioShipState = ScenarioShipState.new()
	state.faction = ScenarioManager.Faction.PIRATE
	ship.scenario_state = state
	add_child_autofree(ship)
	ship.global_position = Vector2(100, 40)

	die = DICE_SCENE.instantiate()
	die.value = 4
	player.add_child(die)
	ship.dice_manager.add(die)
	die.global_position = Vector2(20, 200)


func _spend() -> void:
	var action: EnemyActionEvent = EnemyActionEvent.new()
	action.enemy = ship
	action.activator_die = die
	action.die_value = die.value
	action.action = EnemyActionResource.new()
	action.resolve(null)


func test_the_die_lands_in_front_of_a_ship_that_moved_mid_flight() -> void:
	_spend()
	# A little way out, then the ship slides across the formation.
	ship.spending_tween.custom_step(0.02)
	ship.global_position = Vector2(180, 40)
	ship.spending_tween.custom_step(10.0)

	assert_almost_eq(die.global_position, Vector2(180, 40) + FRONT_OF_SHIP, Vector2.ONE * 0.5,
		"it lands where the ship is, not where it was")


func test_the_die_keeps_station_while_the_ship_is_still_sliding() -> void:
	_spend()
	var flight: float = 0.95 / Globals.animation_speed
	# Past the flight and into the beat before the action fires.
	ship.spending_tween.custom_step(flight + 0.01)
	assert_true(ship.spending_tween.is_running(), "still holding before the action")
	ship.global_position = Vector2(60, 50)
	ship.spending_tween.custom_step(0.01)

	assert_almost_eq(die.global_position, Vector2(60, 50) + FRONT_OF_SHIP, Vector2.ONE * 0.5,
		"the die follows the ship through the hold")


func test_the_die_still_lands_if_its_ship_is_freed_mid_flight() -> void:
	_spend()
	ship.spending_tween.custom_step(0.02)
	var last_front: Vector2 = ship.global_position + FRONT_OF_SHIP
	var tween: Tween = ship.spending_tween
	ship.free()
	tween.custom_step(10.0)

	assert_almost_eq(die.global_position, last_front, Vector2.ONE * 0.5,
		"where the ship was last seen")
