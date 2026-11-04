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
var _previous_scheme: InputBindings.ControlScheme
var _previous_placement: Draggable.PlacementMode


func before_each() -> void:
	super()
	_previous_scheme = InputManager.control_scheme
	_previous_placement = Draggable.placement_mode
	cursor = VirtualCursor.new()
	cursor.attach(get_tree().root)
	focus_sel = FocusSelection.new()
	get_tree().root.add_child(focus_sel)
	autofree(focus_sel)
	focus_sel.attach(cursor, get_tree().root)
	InputManager.control_scheme = InputBindings.ControlScheme.FOCUS


func after_each() -> void:
	InputManager.control_scheme = _previous_scheme
	Draggable.placement_mode = _previous_placement
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


func test_selection_forces_click_even_when_drag_is_requested() -> void:
	OptionsSettings.set_option(OptionsSettings.CONTROLLER_SCHEME, InputBindings.ControlScheme.FOCUS)
	OptionsSettings.set_option(OptionsSettings.DICE_PLACEMENT, Draggable.PlacementMode.DRAG)
	assert_eq(Draggable.placement_mode, Draggable.PlacementMode.CLICK)
	OptionsSettings.set_option(OptionsSettings.CONTROLLER_SCHEME, InputBindings.ControlScheme.CURSOR)
	OptionsSettings.set_option(OptionsSettings.DICE_PLACEMENT, Draggable.PlacementMode.DRAG)
	assert_eq(Draggable.placement_mode, Draggable.PlacementMode.DRAG)


func test_a_uses_custom_button_action() -> void:
	var button: Button = add_child_autofree(load("res://Source/Systems/UI/Buttons/medium_button.tscn").instantiate())
	watch_signals(button)
	focus_sel._current_target = {"type": &"button", "pos": Vector2.ZERO, "node": button}
	focus_sel._activate()
	assert_signal_emitted(button, "pressed_within_window")
	button.disabled = true
	watch_signals(button)
	focus_sel._activate()
	assert_signal_emit_count(button, "pressed_within_window", 1)


func test_a_toggles_checkbox() -> void:
	var box: CheckBox = add_child_autofree(CheckBox.new())
	focus_sel._current_target = {"type": &"button", "pos": Vector2.ZERO, "node": box}
	focus_sel._activate()
	assert_true(box.button_pressed)


func test_modal_without_buttons_blocks_gameplay_and_repeated_info() -> void:
	var shower: Control = add_child_autofree(INFO_SHOWER.instantiate())
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = TEST_TILE_RES
	add_child_autofree(tile)
	focus_sel._current_target = {"type": &"tile_slot", "pos": Vector2.ZERO, "node": tile}
	shower.show()
	focus_sel.refresh()
	assert_eq(focus_sel._modal, shower)
	assert_true(focus_sel._current_target.is_empty())
	watch_signals(Events)
	focus_sel._show_info()
	focus_sel._show_info()
	assert_signal_not_emitted(Events, "show_info")


func test_closing_menu_removes_old_targets() -> void:
	var pause: PauseMenu = add_child_autofree(PAUSE_MENU.instantiate())
	pause.show()
	focus_sel.refresh()
	assert_false(focus_sel._targets.is_empty())
	pause.hide()
	focus_sel.refresh()
	assert_null(focus_sel._modal)
	for target: Dictionary in focus_sel._targets:
		var node: Node = target.get("node")
		assert_false(node != null and pause.is_ancestor_of(node))


func test_dropdown_list_excludes_underlying_menu_buttons() -> void:
	var menu: Node2D = add_child_autofree(OPTIONS_MENU.instantiate())
	menu.show()
	await get_tree().process_frame
	var dropdown: PixelDropdown = null
	for node: Node in menu.find_children("*", "", true, false):
		if node is PixelDropdown and node.is_visible_in_tree() and not node.disabled:
			dropdown = node
			break
	assert_not_null(dropdown)
	if dropdown == null:
		return
	dropdown._open_popup()
	await get_tree().process_frame
	focus_sel.refresh()
	assert_eq(focus_sel._modal, dropdown._popup_panel)
	for target: Dictionary in focus_sel._targets:
		assert_true(dropdown._popup_panel.is_ancestor_of(target.node))
	dropdown._close_popup()


func test_refresh_updates_moving_target_coordinates() -> void:
	var player: Player = add_child_autofree(PLAYER_SCENE.instantiate())
	Globals.player = player
	var die: Dice = DICE_SCENE.instantiate()
	player.add_child(die)
	player.dice_manager.add(die)
	focus_sel.refresh()
	die.global_position = Vector2(123, 142)
	focus_sel.refresh()
	assert_eq(focus_sel._current_target.get("pos"), die.global_position)


func test_mouse_and_keyboard_hide_reticle() -> void:
	InputManager.set_prompt_device(false)
	focus_sel._process(0.016)
	assert_false(focus_sel._reticle_draw.visible)


func test_disabled_dice_placement_is_dimmed_on_both_pages() -> void:
	OptionsSettings.set_option(OptionsSettings.CONTROLLER_SCHEME, InputBindings.ControlScheme.FOCUS)
	var menu: Node2D = add_child_autofree(OPTIONS_MENU.instantiate())
	var count: int = 0
	for page: OptionsPage in menu._pages[OptionsMenu.Tab.CONTROLS]:
		page.refresh()
		for node: Node in page.find_children("*", "", true, false):
			if node is PixelDropdown and node.items.has("OPT_DICE_PLACEMENT_CLICK"):
				assert_eq(node.selected, 1)
				assert_true(node.disabled)
				assert_lt(page._row_of(node).modulate.a, 1.0)
				count += 1
	assert_eq(count, 2)


func test_a_carries_die_until_next_activation() -> void:
	OptionsSettings.set_option(OptionsSettings.CONTROLLER_SCHEME, InputBindings.ControlScheme.FOCUS)
	var die: Dice = add_child_autofree(DICE_SCENE.instantiate())
	focus_sel._current_target = {"type": &"die", "pos": die.global_position, "node": die}
	focus_sel._activate()
	await get_tree().process_frame
	assert_eq(Draggable.holding(), die.draggable)
	assert_true(die.draggable.is_carried())
	focus_sel._cancel()
	assert_null(Draggable.holding())


func test_nested_confirmation_takes_precedence_over_options_and_pause() -> void:
	var pause: PauseMenu = add_child_autofree(PAUSE_MENU.instantiate())
	pause.show()
	var menu: OptionsMenu = pause.find_child("OptionsMenu", true, false) as OptionsMenu
	menu.show()
	focus_sel.refresh()
	assert_eq(focus_sel._modal, menu)
	var dialog: ConfirmDialog = menu.find_child("ConfirmDialog", true, false) as ConfirmDialog
	dialog.open("Test confirmation")
	focus_sel.refresh()
	assert_eq(focus_sel._modal, dialog)
	for target: Dictionary in focus_sel._targets:
		assert_true(dialog.is_ancestor_of(target.node))


func test_left_and_right_adjust_focused_slider() -> void:
	var slider: HSlider = add_child_autofree(HSlider.new())
	slider.step = 0.1
	slider.value = 0.5
	focus_sel._current_target = {"type": &"button", "pos": Vector2.ZERO, "node": slider}
	focus_sel._step(FocusSelection.Direction.RIGHT)
	assert_almost_eq(slider.value, 0.6, 0.001)
	focus_sel._step(FocusSelection.Direction.LEFT)
	assert_almost_eq(slider.value, 0.5, 0.001)


func test_left_stick_is_consumed_before_gui_navigation() -> void:
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.8
	assert_true(focus_sel.handle_event(motion))


func test_focus_scrolls_clipped_controls_into_view() -> void:
	var scroll: ScrollContainer = add_child_autofree(ScrollContainer.new())
	scroll.size = Vector2(120, 60)
	var rows: VBoxContainer = VBoxContainer.new()
	scroll.add_child(rows)
	for i: int in 12:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(100, 25)
		rows.add_child(button)
	await get_tree().process_frame
	await get_tree().process_frame
	var last: Button = rows.get_child(11) as Button
	focus_sel._set_target({"type": &"button", "pos": last.get_global_rect().get_center(), "node": last})
	assert_gt(scroll.scroll_vertical, 0)
	await get_tree().process_frame
	assert_true(scroll.get_global_rect().encloses(last.get_global_rect()))
	FocusSelection._to_screen(focus_sel._current_target)
	assert_eq(FocusSelection._screen_of(focus_sel._current_target), last.get_global_rect().get_center())


func test_info_shower_restores_original_grid_cell() -> void:
	var grid: TileGrid = add_child_autofree(TileGrid.new())
	Globals.tile_grid = grid
	var shower: Control = add_child_autofree(INFO_SHOWER.instantiate())
	shower.hide()
	focus_sel.refresh()
	var original: Dictionary = focus_sel._targets.back()
	focus_sel._set_target(original)
	shower.show()
	focus_sel.refresh()
	shower.hide()
	focus_sel.refresh()
	assert_eq(focus_sel._current_target.get("cell"), original.get("cell"))


func test_horizontal_tabs_override_diagonal_grid_candidates() -> void:
	var systems: Node2D = add_child_autofree(Node2D.new())
	systems.name = "SystemsButton"
	var map_button: Node2D = add_child_autofree(Node2D.new())
	map_button.name = "MapButton"
	var tab: Dictionary = {"type": &"button", "pos": Vector2(100, 100), "node": systems}
	var other: Dictionary = {"type": &"button", "pos": Vector2(300, 100), "node": map_button}
	focus_sel._targets = [tab, other, {"type": &"tile_slot", "pos": Vector2(120, 120), "cell": Vector2i.ZERO}]
	focus_sel._set_target(tab)
	focus_sel._step(FocusSelection.Direction.RIGHT)
	assert_eq(focus_sel._current_target.get("node"), map_button)
	focus_sel._step(FocusSelection.Direction.LEFT)
	assert_eq(focus_sel._current_target.get("node"), systems)


func test_returning_die_regains_focus_when_available() -> void:
	var player: Player = add_child_autofree(PLAYER_SCENE.instantiate())
	Globals.player = player
	var first: Dice = DICE_SCENE.instantiate()
	var returning: Dice = DICE_SCENE.instantiate()
	player.add_child(first)
	player.add_child(returning)
	player.dice_manager.add(first)
	player.dice_manager.add(returning)
	returning.draggable.out_of_reach = true
	focus_sel._returning_die = weakref(returning)
	focus_sel.refresh()
	assert_eq(focus_sel._current_target.get("node"), first)
	returning.draggable.out_of_reach = false
	focus_sel.refresh()
	assert_eq(focus_sel._current_target.get("node"), returning)


func test_offer_pickup_uses_existing_drag_flow() -> void:
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = TEST_TILE_RES
	tile.on_offer = true
	add_child_autofree(tile)
	var targets: Array[Dictionary] = []
	focus_sel._collect_offer_items(tile, targets)
	assert_eq(targets.size(), 1)
	focus_sel._set_target(targets[0])
	focus_sel._activate()
	assert_eq(Draggable.holding(), tile.draggable)
	focus_sel._cancel()


func test_map_targets_include_hand_dice_and_exclude_knob_and_scenarios() -> void:
	var player: Player = add_child_autofree(PLAYER_SCENE.instantiate())
	Globals.player = player
	var die: Dice = DICE_SCENE.instantiate()
	player.add_child(die)
	player.dice_manager.add(die)
	var viewer: MainViewer = add_child_autofree(load("res://Source/Systems/Game/MainViewer/main_viewer.tscn").instantiate())
	var map_node: Map = viewer.map
	map_node.show()
	var targets: Array[Dictionary] = focus_sel._collect_map_targets(map_node)
	assert_true(targets.any(func(t: Dictionary) -> bool: return t.get("node") == die))
	assert_false(targets.any(func(t: Dictionary) -> bool: return t.get("type") == &"waypoint" or t.get("node") is Slider))
	focus_sel._targets = targets
	focus_sel._set_target(targets[0])
	focus_sel._activate()
	assert_eq(focus_sel._current_target.get("type"), &"tile_slot")
	assert_true(focus_sel._current_target.get("node") in [map_node.left_arrow_tile, map_node.right_arrow_tile])
	focus_sel._cancel()
