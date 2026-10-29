extends "res://test/helpers/die_fighter_test.gd"
## Click placement (Controls > Dice Placement): one click picks a die or tile
## up, the next puts it down under the same drop rules a drag lets go into, and
## a right click or cancel puts it back. Drag mode is left exactly as it was:
## the drop comes on the release.
##
## Every click goes through Input as plain mouse button events, the way a
## mouse or a gamepad's virtual cursor sends them, and reaches the Area2Ds by
## the viewport's own physics picking.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const REWARD_SCENE: PackedScene = preload("res://Source/Systems/Game/RewardManager/reward.tscn")
## A real tile, art and all, for the info screen to show.
const ABLATIVE_CHARGE: TileResource = preload("res://Source/Content/Tiles/TileResources/ablative_charge.tres")

## Nowhere near the grid, the hand or an offer.
const _NOWHERE: Vector2 = Vector2(1500, 900)


## Counts the left clicks that reach it. Placed ahead of everything else in
## the tree, it hears _input after them all, and nothing else (a button, a die
## underneath, the GUI) should hear a click spent on a drop either.
class ClickWitness extends Node:
	var clicks: int = 0

	func _input(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			clicks += 1


var player: Player
var grid: TileGrid
var drops: Array[Vector2] = []


func before_each() -> void:
	super()
	Draggable.placement_mode = Draggable.PlacementMode.CLICK
	grid = TileGrid.new()
	grid.position = Vector2(88, 90)
	add_child_autofree(grid)
	Globals.tile_grid = grid
	player = add_child_autofree(PLAYER_SCENE.instantiate())
	player.position = Vector2(40, 140)
	Globals.player = player
	drops.clear()
	infos_shown = 0


func after_each() -> void:
	# Never leave the button held down for the next test.
	_send(_button(MOUSE_BUTTON_LEFT, false, _NOWHERE))
	Draggable.placement_mode = Draggable.PlacementMode.DRAG
	Globals.mouse_is_dragging_something = false
	super()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _hand_die(face: int = 3) -> Dice:
	var die: Dice = DICE_SCENE.instantiate()
	die.value = face
	player.add_child(die)
	player.dice_manager.add(die)
	die.global_position = die.draggable.home_position
	die.draggable.drag_ended.connect(func(_d: Draggable, at: Vector2) -> void: drops.append(at))
	return die


## A grid tile that takes any die, any number of times, unless it's given
## [param resource] to be instead.
func _open_tile(cell: Vector2i = Vector2i(0, 0), resource: TileResource = null) -> Tile:
	var tile: Tile = TILE_SCENE.instantiate()
	if resource:
		tile.tile_resource = resource
	else:
		tile.tile_resource = TileResource.new()
		tile.tile_resource.uses_per_turn = -1
	grid.add_child(tile)
	grid._assign_tile_to_grid_pos(tile, cell, false)
	tile.global_position = tile.draggable.home_position
	return tile


## A mouse button event at world point [param at]. Input takes window
## coordinates and scales them into the viewport (a headless window is far
## smaller than the 1920x1080 viewport), so the point is mapped out first.
func _button(index: MouseButton, pressed: bool, at: Vector2) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	var on_window: Vector2 = get_tree().root.get_final_transform() * at
	event.position = on_window
	event.global_position = on_window
	return event


func _assert_dropped_at(expected: Vector2) -> void:
	assert_eq(drops.size(), 1, "one drop")
	if drops.size() == 1:
		assert_almost_eq(drops[0], expected, Vector2.ONE * 0.5, "dropped where clicked")


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## A full click (press and release) at [param at], through Input. Each half
## gets physics frames, as a hand's click does, for picking to hear it; and
## anything just made has a physics frame to join the space before it's
## picked from.
func _click(at: Vector2, index: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	await wait_physics_frames(2)
	_send(_button(index, true, at))
	await wait_physics_frames(2)
	_send(_button(index, false, at))
	await wait_physics_frames(2)


func _pick_up_by_click(draggable: Draggable) -> void:
	await _click(draggable.global_position)


func _drop_point(tile: Tile) -> Vector2:
	return tile.can_accept_dice.collision.global_position


# ── Click mode ────────────────────────────────────────────────────────────────

func test_a_click_picks_a_die_up_and_letting_go_leaves_it_up() -> void:
	var die: Dice = _hand_die()
	await _pick_up_by_click(die.draggable)

	assert_eq(die.draggable.state, Draggable.DragState.DRAGGING, "still in hand after the release")
	assert_true(die.draggable.is_carried())
	assert_true(Globals.mouse_is_dragging_something)
	assert_eq(drops.size(), 0, "the pick-up's own release isn't a drop")


func test_the_next_click_on_a_tile_places_the_die() -> void:
	var tile: Tile = _open_tile()
	var die: Dice = _hand_die()
	await _pick_up_by_click(die.draggable)

	await _click(_drop_point(tile))

	_assert_dropped_at(_drop_point(tile))
	assert_has(tile.dice_queue.queue, die, "the tile took it, as from a drag")
	assert_false(player.dice_manager.queue.has(die))
	assert_eq(die.draggable.state, Draggable.DragState.DEFAULT)
	assert_false(die.draggable.is_carried())
	assert_false(Globals.mouse_is_dragging_something)


func test_the_placing_click_goes_no_further() -> void:
	var witness: ClickWitness = add_child_autofree(ClickWitness.new())
	move_child(witness, 0)
	var tile: Tile = _open_tile()
	var die: Dice = _hand_die()
	await _pick_up_by_click(die.draggable)
	var before: int = witness.clicks

	await _click(_drop_point(tile))

	assert_eq(witness.clicks, before, "a button or die under the cursor never sees it")
	await _click(_NOWHERE)
	assert_eq(witness.clicks, before + 1, "and later clicks are the world's again")


func test_a_click_on_nothing_sends_the_die_home() -> void:
	_open_tile()
	var die: Dice = _hand_die()
	var home: Vector2 = die.draggable.home_position
	await _pick_up_by_click(die.draggable)

	await _click(_NOWHERE)

	# Like a drag let go there.
	_assert_dropped_at(_NOWHERE)
	assert_has(player.dice_manager.queue, die)
	assert_eq(die.draggable.state, Draggable.DragState.DEFAULT)
	await wait_seconds(0.5)
	assert_almost_eq(die.global_position, home, Vector2.ONE * 6, "floats back to the hand")


func test_a_right_click_puts_the_die_back() -> void:
	var tile: Tile = _open_tile()
	var die: Dice = _hand_die()
	await _pick_up_by_click(die.draggable)

	# Right over a tile that would take it: cancelling still doesn't place it.
	await _click(_drop_point(tile), MOUSE_BUTTON_RIGHT)

	# Let go where it came from.
	_assert_dropped_at(die.draggable.home_position)
	assert_has(player.dice_manager.queue, die)
	assert_eq(tile.dice_queue.queue.size(), 0)
	assert_eq(die.draggable.state, Draggable.DragState.DEFAULT)


func test_cancel_puts_the_die_back() -> void:
	var die: Dice = _hand_die()
	await _pick_up_by_click(die.draggable)
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true

	_send(cancel)
	await wait_physics_frames(1)

	assert_eq(drops.size(), 1)
	assert_has(player.dice_manager.queue, die)
	assert_eq(die.draggable.state, Draggable.DragState.DEFAULT)
	assert_false(Globals.mouse_is_dragging_something)


func test_a_die_taken_by_code_mid_carry_ignores_the_next_click() -> void:
	var die: Dice = _hand_die()
	await _pick_up_by_click(die.draggable)

	# An enemy's tractor beam, say.
	die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
	await wait_physics_frames(1)
	await _click(_NOWHERE)

	assert_false(die.draggable.is_carried())
	assert_eq(drops.size(), 0)
	assert_eq(die.draggable.state, Draggable.DragState.MOVING_WITH_CODE)


func test_salvage_is_taken_by_click_too() -> void:
	var offer: Reward = REWARD_SCENE.instantiate()
	# Clear of the grid, where an offer opens over a ship that just died.
	offer.position = Vector2(240, 40)
	add_child_autofree(offer)
	# Shown as Reward._present() shows it, so the cursor can pick from it.
	offer.show()
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = TileResource.new()
	offer.add_child(tile)
	tile.draggable.drag_started.connect(Events.show_systems.emit)
	tile.draggable.drag_ended.connect(offer._end_reward)
	await _pick_up_by_click(tile.draggable)

	await _click(grid.grid_to_global_pos(Vector2i(2, 1)))

	assert_eq(grid.find_tile_pos(tile), Vector2i(2, 1), "dropped into the cell clicked")


func test_cancelling_salvage_leaves_it_on_offer() -> void:
	var offer: Reward = REWARD_SCENE.instantiate()
	# Clear of the grid, where an offer opens over a ship that just died.
	offer.position = Vector2(240, 40)
	add_child_autofree(offer)
	# Shown as Reward._present() shows it, so the cursor can pick from it.
	offer.show()
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = TileResource.new()
	offer.add_child(tile)
	tile.draggable.drag_ended.connect(offer._end_reward)
	await _pick_up_by_click(tile.draggable)

	await _click(_NOWHERE, MOUSE_BUTTON_RIGHT)

	assert_eq(tile.get_parent(), offer, "still on offer")
	assert_eq(grid.find_tile_pos(tile), Vector2i(-1, -1))
	assert_true(tile.draggable.drag_ended.is_connected(offer._end_reward), "can be taken later")


# ── Tile info ─────────────────────────────────────────────────────────────────

var infos_shown: int = 0


func _count_info(_info: InfoResource) -> void:
	infos_shown += 1


## A click on a tile, which both its Area2Ds hear: the Clickable that shows
## its info and the Draggable that lifts it.
func _click_tile(tile: Tile) -> void:
	await _click(tile.global_position)


func test_picking_a_tile_up_by_click_doesnt_open_its_info() -> void:
	Events.show_info.connect(_count_info)
	var tile: Tile = _open_tile(Vector2i(1, 1), ABLATIVE_CHARGE)
	tile.draggable.drag_ended.connect(grid._drop_tile_on_grid_pos)

	await _click_tile(tile)

	assert_true(tile.draggable.is_carried())
	assert_eq(infos_shown, 0, "a click that lifts a tile is just a lift")
	Events.show_info.disconnect(_count_info)


func test_clicking_a_lifted_tile_again_in_place_shows_its_info() -> void:
	Events.show_info.connect(_count_info)
	var tile: Tile = _open_tile(Vector2i(1, 1), ABLATIVE_CHARGE)
	tile.draggable.drag_ended.connect(grid._drop_tile_on_grid_pos)
	var cell_centre: Vector2 = tile.global_position
	await _click_tile(tile)

	await _click(cell_centre)

	assert_eq(infos_shown, 1)
	assert_false(tile.draggable.is_carried())
	assert_eq(grid.find_tile_pos(tile), Vector2i(1, 1), "and it stays put")
	Events.show_info.disconnect(_count_info)


func test_a_lifted_tile_clicked_elsewhere_moves_without_info() -> void:
	Events.show_info.connect(_count_info)
	var tile: Tile = _open_tile(Vector2i(1, 1), ABLATIVE_CHARGE)
	tile.draggable.drag_ended.connect(grid._drop_tile_on_grid_pos)
	await _click_tile(tile)

	await _click(grid.grid_to_global_pos(Vector2i(3, 0)))

	assert_eq(grid.find_tile_pos(tile), Vector2i(3, 0))
	assert_eq(infos_shown, 0)
	Events.show_info.disconnect(_count_info)


func test_drag_mode_quick_click_still_shows_info() -> void:
	Draggable.placement_mode = Draggable.PlacementMode.DRAG
	Events.show_info.connect(_count_info)
	var tile: Tile = _open_tile(Vector2i(1, 1), ABLATIVE_CHARGE)
	tile.draggable.drag_ended.connect(grid._drop_tile_on_grid_pos)

	await _click_tile(tile)

	assert_eq(infos_shown, 1)
	assert_eq(tile.draggable.state, Draggable.DragState.DEFAULT)
	assert_eq(grid.find_tile_pos(tile), Vector2i(1, 1))
	Events.show_info.disconnect(_count_info)


# ── Drag mode, as it always was ───────────────────────────────────────────────

func test_drag_mode_drops_on_the_release() -> void:
	Draggable.placement_mode = Draggable.PlacementMode.DRAG
	var die: Dice = _hand_die()
	_send(_button(MOUSE_BUTTON_LEFT, true, die.global_position))
	await wait_physics_frames(3)

	assert_eq(die.draggable.state, Draggable.DragState.DRAGGING, "held while the button is")
	assert_false(die.draggable.is_carried(), "a drag is never carried")

	_send(_button(MOUSE_BUTTON_LEFT, false, _NOWHERE))
	await wait_physics_frames(2)

	assert_eq(die.draggable.state, Draggable.DragState.DEFAULT)
	assert_eq(drops.size(), 1, "let go on the release")
	assert_has(player.dice_manager.queue, die)
	assert_false(Globals.mouse_is_dragging_something)


func test_drag_mode_never_waits_for_a_second_click() -> void:
	Draggable.placement_mode = Draggable.PlacementMode.DRAG
	var die: Dice = _hand_die()
	await _pick_up_by_click(die.draggable)

	assert_eq(die.draggable.state, Draggable.DragState.DEFAULT)
	assert_eq(drops.size(), 1)


# ── The cursor's grip ─────────────────────────────────────────────────────────

const _CURSOR_SCRIPT: GDScript = preload("res://Source/Systems/UI/MouseCursor/mouse_cursor.gd")
const _GRAB: Texture2D = preload("res://Assets/Textures/UI/MouseCursors/grab_cursor_raw.png")
const _GRAB_INFO: Texture2D = preload("res://Assets/Textures/UI/MouseCursors/grab_info_cursor_raw.png")


## The game's cursor, as main.tscn mounts it: on its own layer, 6x.
func _cursor() -> Sprite2D:
	var layer: CanvasLayer = add_child_autofree(CanvasLayer.new())
	var cursor: Sprite2D = Sprite2D.new()
	cursor.scale = Vector2(6, 6)
	cursor.centered = false
	cursor.set_script(_CURSOR_SCRIPT)
	layer.add_child(cursor)
	_CURSOR_SCRIPT.set("_carry_hints_given", 0)
	return cursor


func _point_at(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	var on_window: Vector2 = get_tree().root.get_final_transform() * at
	motion.position = on_window
	motion.global_position = on_window
	_send(motion)
	await wait_process_frames(2)


func _hint_of(cursor: Sprite2D) -> Label:
	for child: Node in cursor.get_children():
		if child is Label:
			return child
	return null


func test_whatever_is_lifted_is_held_until_it_lands() -> void:
	var die: Dice = _hand_die()
	assert_null(Draggable.holding())
	await _pick_up_by_click(die.draggable)
	assert_eq(Draggable.holding(), die.draggable)

	await _click(_NOWHERE)
	assert_null(Draggable.holding())


func test_a_die_taken_by_code_is_no_longer_held() -> void:
	var die: Dice = _hand_die()
	await _pick_up_by_click(die.draggable)
	die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
	assert_null(Draggable.holding())


func test_the_info_spot_is_where_the_lift_landed() -> void:
	var tile: Tile = _open_tile(Vector2i(1, 1), ABLATIVE_CHARGE)
	tile.draggable.drag_ended.connect(grid._drop_tile_on_grid_pos)
	var cell_centre: Vector2 = tile.global_position
	await _click_tile(tile)
	await _point_at(cell_centre)
	assert_true(tile.draggable.is_over_info_spot(), "a click here would show its info")

	await _point_at(grid.grid_to_global_pos(Vector2i(3, 0)))
	assert_false(tile.draggable.is_over_info_spot(), "a click here would move it")


func test_a_drag_has_no_info_spot() -> void:
	Draggable.placement_mode = Draggable.PlacementMode.DRAG
	var tile: Tile = _open_tile(Vector2i(1, 1), ABLATIVE_CHARGE)
	await wait_physics_frames(2)
	_send(_button(MOUSE_BUTTON_LEFT, true, tile.global_position))
	await wait_physics_frames(2)
	assert_eq(Draggable.holding(), tile.draggable, "held while the button is down")
	assert_false(tile.draggable.is_over_info_spot())
	_send(_button(MOUSE_BUTTON_LEFT, false, tile.global_position))
	await wait_physics_frames(2)


func test_the_cursor_is_a_fist_while_holding_with_an_i_on_the_info_spot() -> void:
	var cursor: Sprite2D = _cursor()
	var tile: Tile = _open_tile(Vector2i(1, 1), ABLATIVE_CHARGE)
	tile.draggable.drag_ended.connect(grid._drop_tile_on_grid_pos)
	var cell_centre: Vector2 = tile.global_position
	await _click_tile(tile)
	await _point_at(cell_centre)
	assert_eq(cursor.texture, _GRAB_INFO)
	assert_eq(_hint_of(cursor).text, tr("CURSOR_HINT_CLICK_FOR_INFO"))

	await _point_at(grid.grid_to_global_pos(Vector2i(3, 0)))
	assert_eq(cursor.texture, _GRAB)
	assert_eq(_hint_of(cursor).text, tr("CURSOR_HINT_CLICK_TO_PLACE"))

	await _click(grid.grid_to_global_pos(Vector2i(3, 0)))
	await wait_process_frames(1)
	assert_ne(cursor.texture, _GRAB, "let go, the fist opens")
	assert_ne(cursor.texture, _GRAB_INFO)


func test_the_hint_line_teaches_the_first_few_lifts_only() -> void:
	var cursor: Sprite2D = _cursor()
	var die: Dice = _hand_die()
	for lift: int in _CURSOR_SCRIPT.CARRY_HINT_PICKUPS:
		await _pick_up_by_click(die.draggable)
		await wait_process_frames(1)
		var hint: Label = _hint_of(cursor)
		assert_true(hint.visible, "lift %d is told" % lift)
		# A die has no info panel, so there's no spot to click for one.
		assert_eq(hint.text, tr("CURSOR_HINT_CLICK_TO_PLACE"))
		await _click(_NOWHERE)
		await wait_process_frames(1)
		assert_false(hint.visible, "gone with the drop")
		die.global_position = die.draggable.home_position

	await _pick_up_by_click(die.draggable)
	await wait_process_frames(1)
	assert_false(_hint_of(cursor).visible, "by now the player knows")


# ── The option ────────────────────────────────────────────────────────────────

func test_the_option_sets_the_mode_and_defaults_to_drag() -> void:
	OptionsSettings.set_option(OptionsSettings.DICE_PLACEMENT, Draggable.PlacementMode.CLICK)
	assert_eq(Draggable.placement_mode, Draggable.PlacementMode.CLICK)
	assert_eq(OptionsSettings.get_option(OptionsSettings.DICE_PLACEMENT), Draggable.PlacementMode.CLICK)
	assert_eq(OptionsSettings.get_default(OptionsSettings.DICE_PLACEMENT), Draggable.PlacementMode.DRAG)
	# A hand-edited settings file can't leave it in a mode that doesn't exist.
	OptionsSettings.set_option(OptionsSettings.DICE_PLACEMENT, 7)
	assert_eq(Draggable.placement_mode, Draggable.PlacementMode.DRAG)
