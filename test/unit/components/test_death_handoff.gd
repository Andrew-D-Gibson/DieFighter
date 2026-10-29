extends "res://test/helpers/die_fighter_test.gd"
## A destroyed ship's dice change hands at once, but hang at the wreck before
## they cross to their new holder, slowly enough to follow, and land wherever
## that holder has got to.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const INTERCEPTOR: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/interceptor.tres")

var player: Player
var dying: Enemy
var heir: Enemy
var die: Dice


func before_each() -> void:
	super()
	player = add_child_autofree(PLAYER_SCENE.instantiate())
	Globals.enemy_manager = autofree(EnemyManager.new())
	dying = _ship(Vector2(60, 40))
	heir = _ship(Vector2(200, 40))
	Globals.enemy_manager.enemies = [dying, heir] as Array[Enemy]
	die = DICE_SCENE.instantiate()
	die.value = 5
	player.add_child(die)
	dying.dice_manager.add(die)
	die.global_position = dying.dice_manager.global_position


func _ship(at: Vector2) -> Enemy:
	var ship: Enemy = ENEMY_SCENE.instantiate()
	ship.enemy_resource = INTERCEPTOR
	var state: ScenarioShipState = ScenarioShipState.new()
	state.faction = ScenarioManager.Faction.PIRATE
	ship.scenario_state = state
	add_child_autofree(ship)
	ship.global_position = at
	return ship


func _kill_dying_ship() -> Vector2:
	var wreck: Vector2 = die.global_position
	dying.health.change_health(-dying.health.health)
	return wreck


func _handoff() -> Tween:
	return die.get("_handoff_tween") as Tween


func test_the_die_changes_hands_at_once_but_lingers_at_the_wreck() -> void:
	var wreck: Vector2 = _kill_dying_ship()

	assert_eq(die.host_queue, heir.dice_manager, "the new holder has it straight away")
	assert_true(die.is_handing_off())
	_handoff().custom_step(0.3 / Globals.animation_speed)
	assert_almost_eq(die.global_position, wreck, Vector2.ONE * 0.01,
		"still hanging where the ship died")


func test_the_die_lands_with_its_new_holder_and_is_let_go() -> void:
	_kill_dying_ship()
	_handoff().custom_step(Dice.death_handoff_seconds() + 0.01)

	assert_almost_eq(die.global_position, die.draggable.home_position, Vector2.ONE * 0.01)
	assert_false(die.is_handing_off())
	assert_false(die.draggable.held_by_code, "its holder's Draggable has it again")


func test_the_die_lands_where_its_holder_slid_to() -> void:
	_kill_dying_ship()
	# Partway across, the survivor closes the gap the dead ship left.
	_handoff().custom_step(Dice.death_handoff_seconds() * 0.7)
	heir.global_position = Vector2(140, 40)
	heir.dice_manager.update_dice_locations()
	_handoff().custom_step(Dice.death_handoff_seconds())

	assert_almost_eq(die.global_position, die.draggable.home_position, Vector2.ONE * 0.01)
	assert_almost_eq(die.draggable.home_position.x, heir.dice_manager.global_position.x, 0.01,
		"its home moved with the ship")


func test_a_die_crossing_from_a_wreck_cant_be_picked_up() -> void:
	_kill_dying_ship()
	die.draggable.state = Draggable.DragState.DEFAULT
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	die.draggable._on_input_event(null, press, 0)

	assert_ne(die.draggable.state, Draggable.DragState.DRAGGING)


func test_a_ship_spending_the_die_takes_it_off_the_crossing() -> void:
	_kill_dying_ship()
	die.cancel_handoff()
	assert_false(die.is_handing_off())
	assert_false(die.draggable.held_by_code)


func test_a_fleeing_ship_hands_its_dice_straight_over() -> void:
	# No wreck to watch: a ship leaving under its own power just passes them on.
	var flee: FleeEvent = FleeEvent.new()
	flee.actor = dying
	flee.resolve(null)

	assert_eq(die.host_queue, heir.dice_manager)
	assert_false(die.is_handing_off())
