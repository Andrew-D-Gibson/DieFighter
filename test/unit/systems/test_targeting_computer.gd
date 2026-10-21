extends "res://test/helpers/die_fighter_test.gd"
## The targeting computer and where the player's dice aim: a die remembers the
## ship it was dropped against, and the reticle, the icons and a die in flight
## all keep up with a ship that slides across the formation.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const COMPUTER_SCENE: PackedScene = preload("res://Source/Systems/Game/TargetingComputer/targeting_computer.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DAMAGE_TILE: TileResource = preload("res://Source/Content/Tiles/TileResources/damage.tres")
const INTERCEPTOR: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/interceptor.tres")

var player: Player
var computer: TargetingComputer
var manager: EnemyManager
var _animation_speed: float


func before_each() -> void:
	super()
	_animation_speed = Globals.animation_speed
	player = add_child_autofree(PLAYER_SCENE.instantiate())
	manager = autofree(EnemyManager.new())
	Globals.enemy_manager = manager
	Globals.state_manager = autofree(GameStateManager.new())
	computer = add_child_autofree(COMPUTER_SCENE.instantiate())


func after_each() -> void:
	Globals.animation_speed = _animation_speed
	super()


func _ship(at: Vector2 = Vector2.ZERO) -> Enemy:
	var ship: Enemy = ENEMY_SCENE.instantiate()
	ship.enemy_resource = INTERCEPTOR
	var state: ScenarioShipState = ScenarioShipState.new()
	state.faction = ScenarioManager.Faction.PIRATE
	ship.scenario_state = state
	# A bare GameStateManager has no save to scale hull by, and the ship asks
	# for it as it readies. The computer only needs it once a target is up.
	var state_manager: GameStateManager = Globals.state_manager
	Globals.state_manager = null
	add_child_autofree(ship)
	Globals.state_manager = state_manager
	ship.global_position = at
	manager.enemies.append(ship)
	return ship


## A die under the player node, where every die in the game lives.
func _die(face: int = 3) -> Dice:
	var die: Dice = DICE_SCENE.instantiate()
	die.value = face
	player.add_child(die)
	return die


func _target(ship: Enemy) -> void:
	computer.target_enemy(ship)


# ── A queued die remembers its target ─────────────────────────────────────────

func test_a_die_dropped_on_a_tile_remembers_the_ship_targeted_then() -> void:
	var first: Enemy = _ship()
	var second: Enemy = _ship()
	_target(first)
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = DAMAGE_TILE
	add_child_autofree(tile)
	var die: Dice = _die()

	tile._on_die_accepted(die)
	_target(second)

	assert_eq(die.aimed_at, first)
	assert_eq(computer.target_for(die), first, "it still goes where it was sent")


func test_landing_in_a_hand_forgets_the_aim() -> void:
	var ship: Enemy = _ship()
	var die: Dice = _die()
	die.aimed_at = ship
	player.dice_manager.add(die)
	assert_null(die.aimed_at, "the next drop picks its own target")


func test_a_dead_aim_falls_back_to_the_current_target() -> void:
	var first: Enemy = _ship()
	var second: Enemy = _ship()
	var die: Dice = _die()
	die.aimed_at = first
	_target(second)

	first.health.health = 0
	assert_eq(computer.target_for(die), second)


func test_a_ship_that_left_is_no_longer_an_aim() -> void:
	var first: Enemy = _ship()
	var second: Enemy = _ship()
	var die: Dice = _die()
	die.aimed_at = first
	_target(second)

	# Fled: alive, but off the roster.
	manager.enemies.erase(first)
	assert_eq(computer.target_for(die), second)


func test_a_freed_aim_falls_back_quietly() -> void:
	var first: Enemy = _ship()
	var second: Enemy = _ship()
	var die: Dice = _die()
	die.aimed_at = first
	_target(second)

	manager.enemies.erase(first)
	first.free()
	assert_eq(computer.target_for(die), second)


func test_no_die_or_a_stand_in_uses_the_current_target() -> void:
	var ship: Enemy = _ship()
	_target(ship)
	assert_eq(computer.target_for(null), ship)
	assert_eq(computer.target_for(autofree(FakeDie.new(4))), ship)


func test_with_nothing_left_to_target_there_is_no_target() -> void:
	var ship: Enemy = _ship()
	var die: Dice = _die()
	die.aimed_at = ship
	ship.health.health = 0
	computer.check_target_is_valid()
	assert_null(computer.target_for(die))


func test_targeting_handler_hits_the_remembered_ship() -> void:
	var first: Enemy = _ship()
	var second: Enemy = _ship()
	var die: Dice = _die()
	die.aimed_at = first
	_target(second)

	var context := EffectContext.new()
	context.activator_die = die
	TargetWithTargetingComputerHandler.new().apply(null, context, null)
	assert_eq(context.targets, [first] as Array[Node])

	first.health.health = 0
	TargetWithTargetingComputerHandler.new().apply(null, context, null)
	assert_eq(context.targets, [second] as Array[Node])


func test_targeting_checks_ask_about_the_remembered_ship() -> void:
	var first: Enemy = _ship()
	var second: Enemy = _ship()
	var die: Dice = _die()
	die.aimed_at = first
	_target(second)
	second.health.shields = 0
	first.health.shields = 3

	var shields := ActivationResource.new()
	shields.type = ActivationResource.ActivationType.TARGETED_SHIP_HAS_SHIELDS
	assert_true(shields.criteria_satisfied(die), "the die's own target has shields")
	assert_false(shields.criteria_satisfied(null), "the current one doesn't")

	var targeted := ActivationResource.new()
	targeted.type = ActivationResource.ActivationType.SHIP_TARGETED
	assert_true(targeted.criteria_satisfied(die))


# ── Following a moving ship ───────────────────────────────────────────────────

func test_the_reticle_follows_a_targeted_ship_as_it_slides() -> void:
	var ship: Enemy = _ship(Vector2(100, 40))
	_target(ship)
	await wait_seconds(0.4)
	_assert_reticle_on(ship)

	ship.global_position = Vector2(180, 40)
	await wait_physics_frames(2)
	_assert_reticle_on(ship)


func test_the_reticle_follows_mid_glide_too() -> void:
	var first: Enemy = _ship(Vector2(60, 40))
	var second: Enemy = _ship(Vector2(200, 40))
	_target(first)
	await wait_seconds(0.4)
	_target(second)
	# Halfway through the glide, the ship it's headed for moves.
	await wait_seconds(0.1)
	second.global_position = Vector2(260, 40)
	await wait_seconds(0.35)
	_assert_reticle_on(second)


func test_a_redraw_for_the_same_target_does_not_restart_the_glide() -> void:
	var ship: Enemy = _ship(Vector2(100, 40))
	_target(ship)
	await wait_seconds(0.4)
	computer.check_target_is_valid()
	assert_eq(computer._indicator_glide, 1.0, "still settled on the ship")


func _assert_reticle_on(ship: Enemy) -> void:
	var anchor: Vector2 = ship.global_position + computer.targeting_indicator_offset
	var offset: Vector2 = computer.targeting_indicator.global_position - anchor
	assert_true(computer.targeting_indicator.visible)
	# The hover swings it up to (4, 4) off the anchor.
	assert_between(offset.x, -0.01, 4.01, "x within the hover")
	assert_between(offset.y, -0.01, 4.01, "y within the hover")


func test_a_die_in_flight_lands_on_a_ship_that_moved() -> void:
	Globals.animation_speed = 4.0
	var ship: Enemy = _ship(Vector2(100, 40))
	var die: Dice = _die()
	die.global_position = Vector2(160, 200)
	die.draggable.state = Draggable.DragState.MOVING_WITH_CODE

	var attack := AttackTweenEvent.new()
	attack.actor = player
	attack.activator_die = die
	attack.targets = [ship as Node]
	attack.resolve(null)

	await wait_seconds(0.1)
	ship.global_position = Vector2(220, 40)
	await wait_seconds(0.3)
	assert_almost_eq(die.global_position, ship.global_position, Vector2.ONE)


func test_a_die_in_flight_at_a_ship_that_vanishes_lands_where_it_was() -> void:
	Globals.animation_speed = 4.0
	var ship: Enemy = _ship(Vector2(100, 40))
	var die: Dice = _die()
	die.global_position = Vector2(160, 200)
	die.draggable.state = Draggable.DragState.MOVING_WITH_CODE

	var attack := AttackTweenEvent.new()
	attack.actor = player
	attack.activator_die = die
	attack.targets = [ship as Node]
	attack.resolve(null)

	await wait_seconds(0.1)
	manager.enemies.erase(ship)
	ship.free()
	await wait_seconds(0.3)
	assert_almost_eq(die.global_position, Vector2(100, 40), Vector2.ONE)


# ── Icons on a target switch ──────────────────────────────────────────────────

func test_switching_target_stops_a_pulse_and_rests_the_icon() -> void:
	var first: Enemy = _ship()
	var second: Enemy = _ship()
	_target(first)
	computer._pulse_intent(first, 3)
	await wait_seconds(0.2)
	var pulse: Tween = computer.intent_scale_tweens[2]
	assert_true(pulse.is_running())

	_target(second)
	assert_false(pulse.is_valid(), "the old ship's pulse is gone")
	assert_eq(computer._intent(2).scale, Vector2.ONE)


func test_a_redraw_for_the_same_target_lets_a_pulse_finish() -> void:
	var ship: Enemy = _ship()
	_target(ship)
	computer._pulse_intent(ship, 5)
	var pulse: Tween = computer.intent_scale_tweens[4]
	computer.check_target_is_valid()
	assert_true(pulse.is_running(), "nothing changed, so nothing is cut short")


func test_losing_every_target_rests_the_icons_too() -> void:
	var ship: Enemy = _ship()
	_target(ship)
	computer._pulse_intent(ship, 1)
	await wait_seconds(0.2)

	ship.health.health = 0
	computer.check_target_is_valid()
	assert_null(computer.targeted_enemy)
	assert_eq(computer._intent(0).scale, Vector2.ONE)
	assert_false(computer.targeting_indicator.visible)
