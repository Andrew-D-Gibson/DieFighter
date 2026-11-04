extends "res://test/helpers/die_fighter_test.gd"
## Tests for the FOCUS controller scheme, selection reticle, directional stepping,
## dice-to-tile-slot flow, tile info hotkey, and back-button menu closing.

const INFO_SHOWER: PackedScene = preload("res://Source/Systems/UI/InfoShower/info_shower.tscn")
const PAUSE_MENU: PackedScene = preload("res://Source/Systems/UI/PauseMenu/pause_menu.tscn")
const OPTIONS_MENU: PackedScene = preload("res://Source/Systems/UI/OptionsMenu/options_menu.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const TEST_TILE_RES: TileResource = preload("res://Source/Content/Tiles/TileResources/doubler.tres")

var focus_sel: FocusSelection
var cursor: VirtualCursor


func before_each() -> void:
	super()
	cursor = VirtualCursor.new()
	cursor.attach(get_tree().root)
	focus_sel = FocusSelection.new()
	get_tree().root.add_child(focus_sel)
	autofree(focus_sel)
	focus_sel.attach(cursor, get_tree().root)
	InputManager.control_scheme = InputBindings.ControlScheme.FOCUS


func after_each() -> void:
	InputManager.control_scheme = InputBindings.ControlScheme.CURSOR
	super()


static func _action(action_name: StringName, pressed: bool = true) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = action_name
	event.pressed = pressed
	return event


func test_controller_scheme_option_toggles_mode() -> void:
	OptionsSettings.set_option(OptionsSettings.CONTROLLER_SCHEME, InputBindings.ControlScheme.CURSOR)
	assert_eq(InputManager.control_scheme, InputBindings.ControlScheme.CURSOR)

	OptionsSettings.set_option(OptionsSettings.CONTROLLER_SCHEME, InputBindings.ControlScheme.FOCUS)
	assert_eq(InputManager.control_scheme, InputBindings.ControlScheme.FOCUS)


func test_back_button_closes_info_shower() -> void:
	var shower: Control = add_child_autofree(INFO_SHOWER.instantiate())
	shower.show()
	assert_true(shower.visible)

	shower._unhandled_input(_action(&"cursor_back"))
	assert_false(shower.visible)

	shower.show()
	shower._unhandled_input(_action(&"ui_cancel"))
	assert_false(shower.visible)


func test_back_button_closes_options_menu() -> void:
	var menu: Node2D = add_child_autofree(OPTIONS_MENU.instantiate())
	menu.show()
	assert_true(menu.visible)

	menu._unhandled_input(_action(&"cursor_back"))
	assert_false(menu.visible)


func test_back_button_closes_pause_menu() -> void:
	var pause: PauseMenu = add_child_autofree(PAUSE_MENU.instantiate())
	pause.show()
	assert_true(pause.visible)

	pause._unhandled_input(_action(&"cursor_back"))
	assert_false(pause.visible)


func test_directional_stepping_finds_nearest_target() -> void:
	var btn_center: Button = autofree(Button.new())
	btn_center.position = Vector2(500, 500)
	var btn_right: Button = autofree(Button.new())
	btn_right.position = Vector2(600, 500)
	var btn_down: Button = autofree(Button.new())
	btn_down.position = Vector2(500, 600)

	var t_center: Dictionary = {"type": &"button", "pos": Vector2(500, 500), "node": btn_center}
	var t_right: Dictionary = {"type": &"button", "pos": Vector2(600, 500), "node": btn_right}
	var t_down: Dictionary = {"type": &"button", "pos": Vector2(500, 600), "node": btn_down}

	focus_sel._targets = [t_center, t_right, t_down]
	focus_sel._set_target(t_center)

	# Step right
	focus_sel._step(FocusSelection.Direction.RIGHT)
	assert_eq(focus_sel._current_target.get("node"), btn_right)

	# Step left back to center
	focus_sel._step(FocusSelection.Direction.LEFT)
	assert_eq(focus_sel._current_target.get("node"), btn_center)

	# Step down
	focus_sel._step(FocusSelection.Direction.DOWN)
	assert_eq(focus_sel._current_target.get("node"), btn_down)


func test_up_from_die_snaps_to_tile_grid_slot() -> void:
	var grid: TileGrid = add_child_autofree(TileGrid.new())
	grid.position = Vector2(200, 200)
	Globals.tile_grid = grid

	var player: Node2D = add_child_autofree(PLAYER_SCENE.instantiate())
	player.position = Vector2(200, 400)
	Globals.player = player

	var die: Dice = DICE_SCENE.instantiate()
	player.add_child(die)
	player.dice_manager.add(die)
	die.global_position = Vector2(200, 400)

	focus_sel.refresh()
	focus_sel._set_target({
		"type": &"die",
		"pos": die.global_position,
		"rect": Rect2(-11, -11, 22, 22),
		"node": die
	})

	# Up from die should jump to tile grid slot
	focus_sel._step(FocusSelection.Direction.UP)
	assert_eq(focus_sel._current_target.get("type"), &"tile_slot")


func test_b_button_cancels_carried_die() -> void:
	var die: Dice = add_child_autofree(DICE_SCENE.instantiate())
	die.draggable.begin_drag(Vector2(100, 100))
	assert_not_null(Draggable.holding())

	focus_sel._cancel()
	assert_null(Draggable.holding())


func test_x_button_shows_tile_info() -> void:
	watch_signals(Events)
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = TEST_TILE_RES
	add_child_autofree(tile)

	focus_sel._current_target = {
		"type": &"tile_slot",
		"pos": Vector2(100, 100),
		"rect": Rect2(-12, -12, 24, 24),
		"node": tile
	}

	focus_sel._show_info()
	assert_signal_emitted(Events, "show_info")
