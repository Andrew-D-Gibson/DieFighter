extends "res://test/helpers/die_fighter_test.gd"
## Overload: a ship with a breaker skips its turn when the dice it holds add up
## to its threshold. Venting and the rising threshold need a live player to
## hand dice back to, and are verified in a running game (see DEVLOG).

const Ships := preload("res://test/helpers/ships.gd")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")


func _ship(threshold: int) -> Enemy:
	var made: Enemy = Ships.ship(ScenarioManager.Faction.BOSS)
	autofree(made.health)
	made.enemy_resource.overload_threshold = threshold
	made.overload_threshold = threshold
	made.dice_manager = autofree(EnemyDiceManager.new())
	return autofree(made)


func _hold(ship: Enemy, faces: Array[int]) -> void:
	for face: int in faces:
		var die: Dice = autofree(DICE_SCENE.instantiate())
		die.value = face
		ship.dice_manager.queue.append(die)


func test_heat_is_the_total_of_the_held_faces() -> void:
	var ship: Enemy = _ship(15)
	_hold(ship, [6, 5, 2])
	assert_eq(ship.held_heat(), 13)


func test_it_overloads_at_the_threshold_not_before() -> void:
	var ship: Enemy = _ship(15)
	_hold(ship, [6, 6, 2])
	assert_false(ship.is_overloaded(), "14 is short of 15")
	_hold(ship, [1])
	assert_true(ship.is_overloaded(), "15 trips it")


func test_a_ship_without_a_breaker_never_overloads() -> void:
	var ship: Enemy = _ship(0)
	_hold(ship, [6, 6, 6, 6, 6])
	assert_false(ship.is_overloaded())

