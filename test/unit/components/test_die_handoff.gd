extends "res://test/helpers/die_fighter_test.gd"
## A die changing hands arrives squared up for its new holder, whatever was
## moving it on the way out: upright, full size in the player's hand and held
## size with a ship. Rerolls and a ship spending a die end upright too.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const COMPUTER_SCENE: PackedScene = preload("res://Source/Systems/Game/TargetingComputer/targeting_computer.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const INTERCEPTOR: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/interceptor.tres")

const HELD: Vector2 = Vector2.ONE * Dice.HELD_SCALE

var player: Player


func before_each() -> void:
	super()
	player = add_child_autofree(PLAYER_SCENE.instantiate())
	player.num_of_dice = 4


func _ship() -> Enemy:
	var ship: Enemy = ENEMY_SCENE.instantiate()
	ship.enemy_resource = INTERCEPTOR
	var state: ScenarioShipState = ScenarioShipState.new()
	state.faction = ScenarioManager.Faction.PIRATE
	ship.scenario_state = state
	return add_child_autofree(ship)


## A die under the player node, where every die in the game lives.
func _die(face: int = 3) -> Dice:
	var die: Dice = DICE_SCENE.instantiate()
	die.value = face
	player.add_child(die)
	return die


## A die left mid-animation by its last holder: tilted and at an odd size.
func _knock_askew(die: Dice) -> void:
	die.rotation = 2.0
	die.scale = Vector2.ONE * 1.1


func _assert_upright(die: Dice, expected_scale: Vector2, why: String = "") -> void:
	assert_almost_eq(die.rotation, 0.0, 0.001, "upright " + why)
	assert_almost_eq(die.scale, expected_scale, Vector2.ONE * 0.001, "rest scale " + why)


# ── Receiving ─────────────────────────────────────────────────────────────────

func test_a_die_coming_home_to_the_player_is_squared_up() -> void:
	var ship: Enemy = _ship()
	var die: Dice = _die()
	ship.dice_manager.add(die)
	_knock_askew(die)

	player.dice_manager.add(die, true, false)

	_assert_upright(die, Vector2.ONE)


func test_a_die_handed_to_a_ship_is_squared_up_at_its_held_size() -> void:
	var ship: Enemy = _ship()
	var die: Dice = _die()
	_knock_askew(die)

	ship.dice_manager.add(die)

	_assert_upright(die, HELD)


func test_a_die_being_dragged_is_left_to_the_drag() -> void:
	var die: Dice = _die()
	die.draggable.state = Draggable.DragState.DRAGGING
	die.scale = Vector2.ONE * 1.3
	die.rotation = 0.05

	player.dice_manager.add(die, true, false)

	assert_almost_eq(die.scale, Vector2.ONE * 1.3, Vector2.ONE * 0.001)
	assert_almost_eq(die.rotation, 0.05, 0.001)


func test_a_handover_cuts_off_the_old_holders_flourish() -> void:
	# The tractor beam's landing slam, still settling as the die is passed on.
	var ship: Enemy = _ship()
	var die: Dice = _die()
	ship.dice_manager.add(die)
	die.create_flourish_tween().tween_property(die, "scale", HELD, 0.3).from(HELD * 1.4)

	player.dice_manager.add(die, true, false)
	await wait_seconds(0.4)

	_assert_upright(die, Vector2.ONE, "after the slam would have finished")


# ── A dying ship's dice ──────────────────────────────────────────────────────

func test_a_dying_ships_dice_reach_the_next_ship_upright() -> void:
	Globals.enemy_manager = autofree(EnemyManager.new())
	var ship: Enemy = _ship()
	var other: Enemy = _ship()
	Globals.enemy_manager.enemies = [ship, other] as Array[Enemy]
	var die: Dice = _die()
	ship.dice_manager.add(die)
	_knock_askew(die)

	ship.health.change_health(-ship.health.health)

	assert_eq(die.host_queue, other.dice_manager)
	_assert_upright(die, HELD)


func test_a_ship_killed_mid_handover_passes_its_spent_die_on_upright() -> void:
	Globals.enemy_manager = autofree(EnemyManager.new())
	Globals.targeting_computer = add_child_autofree(COMPUTER_SCENE.instantiate())
	var ship: Enemy = _ship()
	var other: Enemy = _ship()
	Globals.enemy_manager.enemies = [ship, other] as Array[Enemy]
	var spending: Dice = _die(6)
	ship.dice_manager.add(spending)

	var action: EnemyActionEvent = EnemyActionEvent.new()
	action.enemy = ship
	action.activator_die = spending
	action.die_value = spending.value
	action.action = EnemyActionResource.new()
	action.resolve(null)
	# Partway through the spin and the grow out in front of the hull.
	await wait_seconds(0.3)

	ship.health.change_health(-ship.health.health)

	assert_eq(spending.host_queue, other.dice_manager)
	_assert_upright(spending, HELD)


# ── Rerolls ──────────────────────────────────────────────────────────────────

func test_a_rerolled_die_lands_upright() -> void:
	# It used to finish half a turn round, face upside down.
	var ship: Enemy = _ship()
	var die: Dice = _die(2)
	ship.dice_manager.add(die)

	await die.reroll_with_tween(5)

	assert_eq(die.value, 5)
	_assert_upright(die, HELD)


func test_a_die_passed_on_mid_reroll_lands_at_its_new_holders_size() -> void:
	var ship: Enemy = _ship()
	var die: Dice = _die(2)
	ship.dice_manager.add(die)

	die.reroll_with_tween(5)
	await wait_seconds(0.1)
	player.dice_manager.add(die, true, false)
	await wait_seconds(0.5)

	assert_eq(die.value, 5)
	_assert_upright(die, Vector2.ONE)


# ── A ship spending a die ────────────────────────────────────────────────────

func test_a_ship_spending_a_die_spins_it_once_and_lands_it_upright() -> void:
	Globals.targeting_computer = add_child_autofree(COMPUTER_SCENE.instantiate())
	var ship: Enemy = _ship()
	var die: Dice = _die(4)
	ship.dice_manager.add(die)

	var action: EnemyActionEvent = EnemyActionEvent.new()
	action.enemy = ship
	action.activator_die = die
	action.die_value = die.value
	action.action = EnemyActionResource.new()
	action.resolve(null)

	var furthest: float = 0.0
	var frames: int = 0
	while ship.spending_tween.is_running() and frames < 600:
		furthest = maxf(furthest, die.rotation)
		await wait_physics_frames(1)
		frames += 1

	assert_gt(furthest, PI, "the die turns over on its way out")
	assert_almost_eq(die.rotation, 0.0, 0.001, "and comes to rest at exactly 0, not a full turn")
