extends "res://test/helpers/die_fighter_test.gd"
## Code taking a held thing out of the player's hands (an enemy grabbing the
## die, the tractor beam, a jump) by setting its Draggable's state. No drop
## happens, but the hold still has to be let go of: the game-wide dragging
## flag, the lift, the wiggle and the carry.

const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")

var die: Dice
var drops: int = 0


func before_each() -> void:
	super()
	drops = 0
	die = DICE_SCENE.instantiate()
	add_child_autofree(die)
	die.draggable.drag_ended.connect(func(_d: Draggable, _at: Vector2) -> void: drops += 1)


func after_each() -> void:
	Draggable.placement_mode = Draggable.PlacementMode.DRAG
	super()


func _pick_up() -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	die.draggable._on_input_event(null, press, 0)


func test_picking_up_lifts_and_holds() -> void:
	var resting_z: int = die.z_index
	_pick_up()
	assert_eq(die.draggable.state, Draggable.DragState.DRAGGING)
	assert_eq(Draggable.holding(), die.draggable)
	assert_eq(die.z_index, resting_z + 10)


func test_code_can_put_something_straight_in_the_hand() -> void:
	watch_signals(die.draggable)
	die.draggable.begin_drag(die.global_position)
	assert_eq(Draggable.holding(), die.draggable, "held, as if the player had pressed on it")
	assert_signal_emitted(die.draggable, "drag_started")
	die.draggable.put_back()
	assert_null(Draggable.holding())


func test_code_taking_it_lets_go_of_the_hold() -> void:
	var resting_z: int = die.z_index
	_pick_up()
	die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
	assert_null(Draggable.holding(), "other things can be hovered and picked up again")
	assert_null(Draggable.held)
	assert_eq(die.z_index, resting_z, "back at its usual depth")
	assert_eq(die.scale, Vector2.ONE)
	assert_false(die.draggable.tween.is_valid(), "the wiggle stops")
	assert_eq(drops, 0, "it wasn't dropped anywhere")


func test_code_taking_a_carried_die_ends_the_carry() -> void:
	Draggable.placement_mode = Draggable.PlacementMode.CLICK
	_pick_up()
	assert_true(die.draggable.is_carried())
	die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
	assert_false(die.draggable.is_carried())
	assert_false(die.draggable.is_processing_input(), "the next click isn't a drop")


func test_a_drop_lets_go_once() -> void:
	var resting_z: int = die.z_index
	_pick_up()
	die.draggable.put_back()
	assert_eq(drops, 1)
	assert_eq(die.z_index, resting_z)
	assert_null(Draggable.holding())
	# A later takeover of a die no longer held changes nothing.
	die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
	assert_eq(die.z_index, resting_z)
