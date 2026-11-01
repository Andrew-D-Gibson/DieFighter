extends "res://test/helpers/die_fighter_test.gd"
## The targeting computer crackles the Arc Dynamo's portrait while its
## overload gauge is armed, and stops when the gauge trips or empties. Ships
## without crackle art (the Zealot) never crackle.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const COMPUTER_SCENE: PackedScene = preload("res://Source/Systems/Game/TargetingComputer/targeting_computer.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const ARC_DYNAMO: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/arc_dynamo.tres")
const ZEALOT: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/zealot.tres")

var computer: TargetingComputer
var manager: EnemyManager


func before_each() -> void:
	super()
	add_child_autofree(PLAYER_SCENE.instantiate())
	manager = autofree(EnemyManager.new())
	Globals.enemy_manager = manager
	Globals.state_manager = autofree(GameStateManager.new())
	computer = add_child_autofree(COMPUTER_SCENE.instantiate())


func _ship(resource: EnemyResource) -> Enemy:
	var ship: Enemy = ENEMY_SCENE.instantiate()
	ship.enemy_resource = resource
	var state: ScenarioShipState = ScenarioShipState.new()
	state.faction = ScenarioManager.Faction.BOSS
	state.attitude = Enemy.Attitude.AGGRESSIVE
	ship.scenario_state = state
	var state_manager: GameStateManager = Globals.state_manager
	Globals.state_manager = null
	add_child_autofree(ship)
	Globals.state_manager = state_manager
	manager.enemies.append(ship)
	return ship


## Fills [param ship] to its threshold exactly.
func _fill(ship: Enemy) -> void:
	var left: int = ship.overload_threshold - ship.held_heat()
	while left > 0:
		var die: Dice = autofree(DICE_SCENE.instantiate())
		die.value = mini(left, 6)
		left -= die.value
		ship.dice_manager.queue.append(die)


func test_armed_arc_dynamo_crackles_until_it_trips() -> void:
	var ship: Enemy = _ship(ARC_DYNAMO)
	computer.target_enemy(ship)
	await wait_process_frames(3)
	assert_false(computer._crackle.is_playing(), "calm: no crackle")
	_fill(ship)
	await wait_process_frames(3)
	assert_eq(ship.overload_gauge.state(), OverloadGauge.State.ARMED)
	assert_true(computer._crackle.is_playing(), "armed: crackles")
	assert_eq(computer._crackle.texture, ARC_DYNAMO.overload_portrait_crackle)
	ship.vent_overload()
	assert_false(computer._crackle.is_playing(), "tripped: stops")


func test_the_crackle_stops_when_the_dice_leave() -> void:
	var ship: Enemy = _ship(ARC_DYNAMO)
	computer.target_enemy(ship)
	_fill(ship)
	await wait_process_frames(3)
	assert_true(computer._crackle.is_playing())
	ship.dice_manager.queue.clear()
	await wait_process_frames(3)
	assert_false(computer._crackle.is_playing())


func test_targeting_away_stops_the_crackle() -> void:
	var dynamo: Enemy = _ship(ARC_DYNAMO)
	var zealot: Enemy = _ship(ZEALOT)
	computer.target_enemy(dynamo)
	_fill(dynamo)
	await wait_process_frames(3)
	assert_true(computer._crackle.is_playing())
	computer.target_enemy(zealot)
	_fill(zealot)
	await wait_process_frames(3)
	assert_eq(zealot.overload_gauge.state(), OverloadGauge.State.ARMED)
	assert_false(computer._crackle.is_playing(), "the Zealot has no crackle art")
	computer.target_enemy(dynamo)
	await wait_process_frames(3)
	assert_true(computer._crackle.is_playing(), "back on the armed Dynamo")
