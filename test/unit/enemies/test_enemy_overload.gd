extends "res://test/helpers/die_fighter_test.gd"
## Overload: a ship with a breaker skips its turn when the dice it holds add up
## to its threshold, and its gauge shows how close it is. Venting held dice
## needs a live player to hand them back to, and is verified in a running game
## (see DEVLOG).

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



# ── The gauge ────────────────────────────────────────────────────────────────

const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const ARC_DYNAMO: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/arc_dynamo.tres")
const ZEALOT: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/zealot.tres")
const INTERCEPTOR: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/interceptor.tres")


## A real ship in the tree, gauge and all.
func _live_ship(resource: EnemyResource) -> Enemy:
	var made: Enemy = ENEMY_SCENE.instantiate()
	made.enemy_resource = resource
	made.scenario_state = ScenarioShipState.new()
	made.scenario_state.faction = ScenarioManager.Faction.BOSS
	made.scenario_state.attitude = Enemy.Attitude.AGGRESSIVE
	# A bare test has no save to scale hull by; the ship asks as it readies.
	var state_manager: GameStateManager = Globals.state_manager
	Globals.state_manager = null
	add_child_autofree(made)
	Globals.state_manager = state_manager
	return made


func test_the_gauge_warns_only_within_a_few_pips() -> void:
	var calm: int = 15 - OverloadGauge.WARN_PIPS - 1
	assert_eq(OverloadGauge.state_for(0, 15), OverloadGauge.State.CALM)
	assert_eq(OverloadGauge.state_for(calm, 15), OverloadGauge.State.CALM)
	assert_eq(OverloadGauge.state_for(calm + 1, 15), OverloadGauge.State.WARNING)
	assert_eq(OverloadGauge.state_for(14, 15), OverloadGauge.State.WARNING)
	assert_eq(OverloadGauge.state_for(15, 15), OverloadGauge.State.ARMED)
	assert_eq(OverloadGauge.state_for(19, 15), OverloadGauge.State.ARMED, "past the limit is still armed")
	assert_eq(OverloadGauge.state_for(6, 0), OverloadGauge.State.CALM, "no breaker, nothing to warn of")


func test_only_a_ship_with_a_breaker_gets_a_gauge() -> void:
	assert_not_null(_live_ship(ARC_DYNAMO).overload_gauge)
	assert_not_null(_live_ship(ZEALOT).overload_gauge)
	assert_null(_live_ship(INTERCEPTOR).overload_gauge)


func test_the_gauge_follows_the_dice_held() -> void:
	var ship: Enemy = _live_ship(ZEALOT)
	var gauge: OverloadGauge = ship.overload_gauge
	_hold(ship, [6, 4])
	await wait_process_frames(3)
	assert_eq(gauge.state(), OverloadGauge.State.WARNING, "10 of 12")
	assert_eq(gauge.label.text, "10/12")
	_hold(ship, [2])
	await wait_process_frames(3)
	assert_eq(gauge.state(), OverloadGauge.State.ARMED, "12 of 12")


func test_tripping_flashes_the_gauge() -> void:
	var ship: Enemy = _live_ship(ARC_DYNAMO)
	watch_signals(ship)
	ship.vent_overload()
	assert_signal_emitted(ship, "overloaded")
	assert_eq(ship.overload_gauge.state(), OverloadGauge.State.TRIPPED)
	assert_eq(ship.overload_threshold, ARC_DYNAMO.overload_threshold + ARC_DYNAMO.overload_threshold_growth)


func test_the_formation_makes_room_for_the_gauge() -> void:
	for resource: EnemyResource in [ARC_DYNAMO, ZEALOT]:
		var ship: Enemy = _live_ship(resource)
		var gauge: OverloadGauge = ship.overload_gauge
		var reach: Vector2 = gauge.reach()
		var footprint: Vector2 = ship.formation_footprint()
		assert_true(footprint.x >= reach.x - gauge.position.x, "%s left" % resource.enemy_name)
		assert_true(footprint.y >= gauge.position.x + reach.y, "%s right" % resource.enemy_name)


func test_the_gauge_says_what_it_is_on_hover() -> void:
	var gauge: OverloadGauge = _live_ship(ZEALOT).overload_gauge
	assert_ne(gauge.clickable.hover_hint, &"")
	assert_ne(tr(gauge.clickable.hover_hint), String(gauge.clickable.hover_hint), "the hint key is translated")
