extends "res://test/helpers/die_fighter_test.gd"
## Confirm End Turn (Game > Confirm End Turn): the player's own End Turn, from
## the button or its key, asks first while a die in hand could still go on a
## tile. Nothing left to play, the option off, or the turn ended by code (the
## AutoPilot, the tutorial) and it ends at once.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")

var player: Player
var grid: TileGrid
var confirm: EndTurnConfirm
var turns_ended: int = 0


func before_each() -> void:
	super()
	EndTurnConfirm.enabled = true
	grid = TileGrid.new()
	grid.position = Vector2(88, 90)
	add_child_autofree(grid)
	Globals.tile_grid = grid
	player = add_child_autofree(PLAYER_SCENE.instantiate())
	Globals.player = player
	confirm = player.get_node("%EndTurnConfirm")
	# The button lights when the turn may end: for an Outrigger, with dice
	# still in hand.
	var button: Button = player.get_node("%EndTurnButton")
	button.disabled = false
	turns_ended = 0
	Events.player_turn_over.connect(_count_turn_end)


func after_each() -> void:
	Events.player_turn_over.disconnect(_count_turn_end)
	EndTurnConfirm.enabled = true
	super()


func _count_turn_end() -> void:
	turns_ended += 1


func _hand_die(face: int = 3) -> Dice:
	var die: Dice = DICE_SCENE.instantiate()
	die.value = face
	player.add_child(die)
	player.dice_manager.add(die)
	return die


func _tile(uses: int = -1) -> Tile:
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = TileResource.new()
	tile.tile_resource.uses_per_turn = uses
	grid.add_child(tile)
	grid._assign_tile_to_grid_pos(tile, grid.find_available_grid_pos(), false)
	return tile


func _action(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()


# ── Asking ────────────────────────────────────────────────────────────────────

func test_ending_with_a_playable_die_asks_first() -> void:
	_tile()
	_hand_die()

	player.request_end_turn()

	assert_true(confirm.is_asking())
	assert_eq(turns_ended, 0, "not until the player says so")

	confirm.get_node("ConfirmDialog")._on_confirm_button_pressed()

	assert_false(confirm.is_asking())
	assert_eq(turns_ended, 1)


func test_cancelling_keeps_the_turn() -> void:
	_tile()
	_hand_die()
	player.request_end_turn()

	confirm.get_node("ConfirmDialog")._on_cancel_button_pressed()

	assert_false(confirm.is_asking())
	assert_eq(turns_ended, 0)
	assert_true(player.can_end_turn(), "and End Turn still works")


func test_escape_backs_out() -> void:
	_tile()
	_hand_die()
	player.request_end_turn()

	_action(&"ui_cancel")

	assert_false(confirm.is_asking())
	assert_eq(turns_ended, 0)


func test_pressing_end_turn_again_confirms() -> void:
	_tile()
	_hand_die()
	player.request_end_turn()
	player.request_end_turn()
	assert_eq(turns_ended, 1)
	assert_false(confirm.is_asking())


func test_the_end_turn_key_asks_too() -> void:
	Globals.state_manager = autofree(GameStateManager.new())
	_tile()
	_hand_die()

	_action(&"EndTurn")
	assert_true(confirm.is_asking(), "InputManager goes through the same check")
	assert_eq(turns_ended, 0)

	_action(&"EndTurn")
	assert_eq(turns_ended, 1, "a second press confirms")


func test_a_turn_that_moved_on_while_asking_isnt_ended_twice() -> void:
	_tile()
	_hand_die()
	player.request_end_turn()
	# Something else ended the turn meanwhile.
	player.end_turn()
	assert_eq(turns_ended, 1)

	confirm.get_node("ConfirmDialog")._on_confirm_button_pressed()

	assert_eq(turns_ended, 1)


# ── Not asking ────────────────────────────────────────────────────────────────

func test_an_empty_hand_ends_at_once() -> void:
	_tile()
	player.request_end_turn()
	assert_false(confirm.is_asking())
	assert_eq(turns_ended, 1)


func test_dice_no_tile_would_take_end_at_once() -> void:
	_tile(0)
	_hand_die()
	assert_eq(EndTurnConfirm.playable_dice(player).size(), 0, "a spent tile takes nothing")

	player.request_end_turn()

	assert_false(confirm.is_asking())
	assert_eq(turns_ended, 1)


func test_locked_dice_end_at_once() -> void:
	_tile()
	var die: Dice = _hand_die()
	die.draggable.dragging_allowed = false

	player.request_end_turn()

	assert_eq(turns_ended, 1)


func test_with_the_option_off_it_never_asks() -> void:
	EndTurnConfirm.enabled = false
	_tile()
	_hand_die()

	player.request_end_turn()

	assert_false(confirm.is_asking())
	assert_eq(turns_ended, 1)


func test_a_disabled_end_turn_does_nothing() -> void:
	player.get_node("%EndTurnButton").disabled = true
	_tile()
	_hand_die()
	player.request_end_turn()
	assert_false(confirm.is_asking())
	assert_eq(turns_ended, 0)


func test_the_auto_pilot_is_never_asked() -> void:
	_tile()
	_hand_die()

	AutoPilotMove.end_turn().perform()

	assert_false(confirm.is_asking())
	assert_eq(turns_ended, 1)


func test_code_ending_the_turn_is_never_asked() -> void:
	# The tutorial, a hazard, a dev command: anything calling end_turn().
	_tile()
	_hand_die()
	player.end_turn()
	assert_false(confirm.is_asking())
	assert_eq(turns_ended, 1)


# ── Click placement ───────────────────────────────────────────────────────────

func test_asking_puts_a_carried_die_back_so_the_dialog_gets_the_click() -> void:
	Draggable.placement_mode = Draggable.PlacementMode.CLICK
	_tile()
	var die: Dice = _hand_die()
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	die.draggable.input_event.emit(get_viewport(), press, 0)
	assert_true(die.draggable.is_carried())

	player.request_end_turn()
	Draggable.placement_mode = Draggable.PlacementMode.DRAG

	assert_true(confirm.is_asking())
	assert_false(die.draggable.is_carried())
	assert_has(player.dice_manager.queue, die)
	Globals.mouse_is_dragging_something = false


# ── The option ────────────────────────────────────────────────────────────────

func test_the_option_drives_it_and_defaults_on() -> void:
	OptionsSettings.set_option(OptionsSettings.CONFIRM_END_TURN, false)
	assert_false(EndTurnConfirm.enabled)
	assert_eq(OptionsSettings.get_default(OptionsSettings.CONFIRM_END_TURN), true)
