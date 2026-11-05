class_name FocusSelection
extends Node
## Snapping selection controller scheme for gamepad support.
## Instead of the stick gliding a pointer freely, an animated selection reticle
## snaps between on-screen objects of interest (dice, tile slots, enemies,
## buttons, tabs, waypoints).
##
## D-pad and Left Stick step between objects.
## A (cursor_click) picks up / confirms / drops.
## B (cursor_back / ui_cancel) puts back a held die or closes the topmost menu / InfoShower.
## X opens InfoShower for the focused tile / object.
## Right Stick scrolls the map horizontally.

signal focus_changed(target_info: Dictionary)

enum Direction { UP, DOWN, LEFT, RIGHT }

var active: bool = false
var position: Vector2 = Vector2.ZERO

var _cursor: VirtualCursor
var _viewport: Viewport

## The current target representation:
## Dictionary with keys:
##   "type": StringName (&"die", &"tile_slot", &"enemy", &"button", &"waypoint", &"custom")
##   "pos": Vector2 (the node's own canvas coordinates: world pixels for the
##          320x180 game, which is what Draggable.begin_drag expects)
##   "rect": Rect2 (bounding box for reticle, in those same units)
##   "screen": Vector2, "screen_rect": Rect2 (added by _collect_targets: the
##          same spot in viewport pixels, where the cursor warps and the
##          reticle draws; see _to_screen)
##   "node": Node (optional underlying node)
##   "cell": Vector2i (for tile slots)
var _current_target: Dictionary = {}
var _targets: Array[Dictionary] = []
var _modal: CanvasItem
var _saved_targets: Dictionary[int, Dictionary] = {}
var _returning_die: WeakRef
var _last_grid_cell: Vector2i = Vector2i(-1, -1)

## Stick navigation timing
const STICK_DEADZONE: float = 0.5
const STICK_INITIAL_DELAY: float = 0.25
const STICK_REPEAT_RATE: float = 0.16

## Viewport pixels per art pixel (the 1920x1080 viewport over the 320x180
## game): the reticle is drawn in whole art pixels so it reads as pixel art.
const _ART_SCALE: float = 6.0
const _RETICLE_COLOR: Color = Color("#EED35D")
const _RETICLE_OUTLINE: Color = Color("#040217")
var _stick_held_dir: int = -1
var _stick_timer: float = 0.0

## Reticle visual
var _reticle_canvas: CanvasLayer
var _reticle_draw: Control
var _reticle_pos: Vector2 = Vector2.ZERO
var _reticle_rect: Rect2 = Rect2(-12, -12, 24, 24)
var _pulse_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_reticle()


func attach(cursor: VirtualCursor, viewport: Viewport) -> void:
	_cursor = cursor
	_viewport = viewport
	active = true


func _setup_reticle() -> void:
	_reticle_canvas = CanvasLayer.new()
	_reticle_canvas.layer = 120
	_reticle_canvas.scale = Vector2(_ART_SCALE, _ART_SCALE)
	_reticle_canvas.name = "FocusReticleLayer"
	add_child(_reticle_canvas)

	_reticle_draw = Control.new()
	_reticle_draw.name = "FocusReticle"
	_reticle_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle_draw.draw.connect(_on_reticle_draw)
	_reticle_canvas.add_child(_reticle_draw)


func _process(delta: float) -> void:
	if not active:
		_reticle_draw.hide()
		return

	# Right stick can scroll the map in both schemes
	_update_right_stick_map(delta)

	if InputManager.control_scheme != InputBindings.ControlScheme.FOCUS or not InputManager.controller_active or InputManager.is_listening():
		if _reticle_draw and _reticle_draw.visible:
			_reticle_draw.hide()
		return

	refresh()
	_reticle_draw.visible = not _current_target.is_empty()

	_pulse_time += delta
	_update_stick_navigation(delta)

	# Keep reticle smooth and following current target
	if not _current_target.is_empty():
		var target_pos: Vector2 = _screen_of(_current_target)
		var target_rect: Rect2 = _current_target.get("screen_rect", _current_target.get("rect", Rect2(-12, -12, 24, 24)))
		_reticle_pos = _reticle_pos.lerp(target_pos, clampf(delta * 25.0, 0.0, 1.0))
		_reticle_rect.size = _reticle_rect.size.lerp(target_rect.size, clampf(delta * 25.0, 0.0, 1.0))
		_reticle_rect.position = -_reticle_rect.size / 2.0
		_reticle_draw.queue_redraw()
	else:
		refresh()


func _on_reticle_draw() -> void:
	if _current_target.is_empty() or not active:
		return
	# Everything in art pixels, snapped, so the brackets sit on the game's grid.
	var center: Vector2 = (_reticle_pos / _ART_SCALE).round()
	var half: Vector2 = (_reticle_rect.size / _ART_SCALE / 2.0).round() + Vector2.ONE
	# The pulse breathes a whole pixel out and back rather than sliding.
	if sin(_pulse_time * 5.0) > 0.0:
		half += Vector2.ONE
	var arm: float = clampf(roundf(minf(half.x, half.y) * 0.6), 2.0, 5.0)
	var corners: Array[Vector2] = [
		center - half, Vector2(center.x + half.x - 1, center.y - half.y),
		Vector2(center.x - half.x, center.y + half.y - 1), center + half - Vector2.ONE]
	var signs: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
	# Outline pass, then the bracket itself, each a 1px-wide L at every corner.
	for pass_idx: int in 2:
		var grow: float = 1.0 if pass_idx == 0 else 0.0
		var color: Color = _RETICLE_OUTLINE if pass_idx == 0 else _RETICLE_COLOR
		for i: int in 4:
			_draw_arm(corners[i], Vector2(signs[i].x * arm, 0), grow, color)
			_draw_arm(corners[i], Vector2(0, signs[i].y * arm), grow, color)


## One 1px-wide arm of a bracket from [param corner] along [param along],
## widened by [param grow] on every side for the outline pass.
func _draw_arm(corner: Vector2, along: Vector2, grow: float, color: Color) -> void:
	var rect: Rect2 = Rect2(corner, Vector2.ONE).merge(Rect2(corner + along - along.sign(), Vector2.ONE))
	_reticle_draw.draw_rect(rect.grow(grow), color)


## Where [param target] sits in viewport pixels. Targets built by hand (and
## tests) without a screen position fall back to "pos".
static func _screen_of(target: Dictionary) -> Vector2:
	return target.get("screen", target.get("pos", Vector2.ZERO))


## Maps [param ref]'s canvas coordinates to the root viewport's pixels,
## through any SubViewport it renders into (the map draws into one shown by
## a TextureRect).
static func _canvas_to_screen(ref: CanvasItem) -> Transform2D:
	var xf: Transform2D = ref.get_canvas_transform()
	var viewport: Viewport = ref.get_viewport()
	while viewport is SubViewport:
		var host: Node = viewport.get_parent()
		var shown_at: Vector2
		if host is TextureRect:
			# The visible rect, not the pixel size: the map draws 120x75 art
			# pixels into a 720x450 texture (size_2d_override).
			shown_at = (host as TextureRect).size / viewport.get_visible_rect().size
		elif host is SubViewportContainer:
			shown_at = Vector2.ONE * float((host as SubViewportContainer).stretch_shrink)
		else:
			break
		var host_item: CanvasItem = host as CanvasItem
		xf = host_item.get_global_transform_with_canvas() * Transform2D.IDENTITY.scaled(shown_at) * xf
		viewport = host_item.get_viewport()
	return xf


## Adds "screen" and "screen_rect": world nodes sit under the 6x camera,
## menus under their own CanvasLayers and the map in a SubViewport, so each
## position is converted through the canvas it was found on.
static func _to_screen(target: Dictionary) -> void:
	var ref: CanvasItem = target.get("node") as CanvasItem
	if not is_instance_valid(ref):
		ref = target.get("grid", target.get("map")) as CanvasItem
	if not is_instance_valid(ref) or not ref.is_inside_tree():
		return
	if ref is Control:
		target["pos"] = ref.get_global_rect().get_center()
		var control_size: Vector2 = ref.get_global_rect().size
		target["rect"] = Rect2(-control_size / 2.0, control_size)
	var xf: Transform2D = _canvas_to_screen(ref)
	var rect: Rect2 = target.get("rect", Rect2(-12, -12, 24, 24))
	target["screen"] = xf * Vector2(target.get("pos", Vector2.ZERO))
	target["screen_rect"] = Rect2(rect.position * xf.get_scale(), rect.size * xf.get_scale())


## Handles controller buttons and d-pad events
func handle_event(event: InputEvent) -> bool:
	if not active or InputManager.control_scheme != InputBindings.ControlScheme.FOCUS:
		return false

	if event is InputEventJoypadMotion:
		return event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]

	if event is InputEventJoypadButton:
		if not event.pressed or event.is_echo():
			return true

		refresh()
		match event.button_index:
			JOY_BUTTON_DPAD_UP:
				_step(Direction.UP)
				return true
			JOY_BUTTON_DPAD_DOWN:
				_step(Direction.DOWN)
				return true
			JOY_BUTTON_DPAD_LEFT:
				_step(Direction.LEFT)
				return true
			JOY_BUTTON_DPAD_RIGHT:
				_step(Direction.RIGHT)
				return true
			JOY_BUTTON_A:
				_activate()
				return true
			JOY_BUTTON_B:
				_cancel()
				return true
			JOY_BUTTON_X:
				_show_info()
				return true
		return false

	return false


## Left stick navigation with repeat
func _update_stick_navigation(delta: float) -> void:
	var stick: Vector2 = Vector2(
		Input.get_joy_axis(maxi(InputManager.active_joypad, 0), JOY_AXIS_LEFT_X),
		Input.get_joy_axis(maxi(InputManager.active_joypad, 0), JOY_AXIS_LEFT_Y)
	)

	var dir: int = -1
	if stick.length() > STICK_DEADZONE:
		if absf(stick.x) > absf(stick.y):
			dir = Direction.RIGHT if stick.x > 0 else Direction.LEFT
		else:
			dir = Direction.DOWN if stick.y > 0 else Direction.UP

	if dir != -1:
		if _stick_held_dir != dir:
			_stick_held_dir = dir
			_stick_timer = STICK_INITIAL_DELAY
			_step(dir)
		else:
			_stick_timer -= delta
			if _stick_timer <= 0.0:
				_stick_timer = STICK_REPEAT_RATE
				_step(dir)
	else:
		_stick_held_dir = -1
		_stick_timer = 0.0


## Right stick horizontal map scrolling
func _update_right_stick_map(delta: float) -> void:
	var map_node: Map = _get_active_map()
	if not map_node or not map_node.is_visible_in_tree() or not InputManager.controller_active:
		return

	var rx: float = Input.get_joy_axis(maxi(InputManager.active_joypad, 0), JOY_AXIS_RIGHT_X)
	if absf(rx) <= 0.2:
		return
	# Looked up here rather than read from _modal, which only refresh() keeps
	# current, and refresh() runs in the FOCUS scheme alone. Only once the
	# stick is pushed: the lookup walks the tree.
	if is_instance_valid(_find_modal()):
		return
	var pan_speed: float = 300.0
	map_node._pan_camera_by(rx * pan_speed * delta)


## Rebuilds the target list and keeps or resets the focus
func refresh() -> void:
	var previous_modal: CanvasItem = _modal
	_targets = _collect_targets()
	if previous_modal != _modal:
		var previous_key: int = previous_modal.get_instance_id() if is_instance_valid(previous_modal) else 0
		_saved_targets[previous_key] = _current_target
		var next_key: int = _modal.get_instance_id() if is_instance_valid(_modal) else 0
		_current_target = _saved_targets.get(next_key, {})
		_reticle_pos = Vector2.ZERO
	if not is_instance_valid(_modal) and _returning_die:
		var die: Dice = _returning_die.get_ref() as Dice
		if not is_instance_valid(die):
			_returning_die = null
		else:
			for target: Dictionary in _targets:
				if target.get("type") == &"die" and target.get("node") == die and not Draggable.holding():
					_current_target = target
					_returning_die = null
					break
	if _targets.is_empty():
		_current_target = {}
		return

	# If currently holding a die and not already on the tile grid, snap to the tile grid
	if Draggable.holding() and not is_instance_valid(_modal) and _current_target.get("type") not in [&"tile_slot", &"sell_zone"]:
		_focus_best_grid_slot()
		return

	# If current target is still valid, retain it
	var found_idx: int = -1
	if not _current_target.is_empty():
		for i: int in range(_targets.size()):
			if _is_same_target(_targets[i], _current_target):
				found_idx = i
				break

	if found_idx >= 0:
		_set_target(_targets[found_idx])
	else:
		# Default focus: if dice exist, first die; else first target
		var default_target: Dictionary = _targets[0]
		for t: Dictionary in _targets:
			if t.get("type") == &"die":
				default_target = t
				break
		_set_target(default_target)


func _collect_targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = _collect_targets_in_canvas()
	for target: Dictionary in result:
		_to_screen(target)
	return result


func _collect_targets_in_canvas() -> Array[Dictionary]:
	# Even a modal without buttons blocks selection of the scene beneath it.
	_modal = _find_modal()
	if is_instance_valid(_modal):
		return _collect_menu_targets()

	# 2. Map Screen
	var map_node: Map = _get_active_map()
	if map_node and map_node.is_visible_in_tree():
		return _collect_map_targets(map_node)

	# 3. Combat / Systems Screen
	return _collect_combat_targets()


## Collect targets for open menus / popups
func _collect_menu_targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if is_instance_valid(_modal):
		_collect_interactive_controls(_modal, result)
	return result


## Resolve overlays in draw order, including nested confirmations and dropdowns.
func _find_modal() -> CanvasItem:
	var candidates: Array[Node] = []
	for group: StringName in [&"modal_menu", &"options_menu", &"pause_menu"]:
		candidates.append_array(get_tree().get_nodes_in_group(group))
	for modal_name: String in ["PauseMenu", "OptionsMenu", "ConfirmDialog", "CodexPopup", "ShipSelectPopup", "InfoShower", "MainMenu", "GameOver"]:
		candidates.append_array(get_tree().root.find_children(modal_name, "", true, false))
	var top: CanvasItem = null
	var top_order: int = -2147483648
	for candidate: Node in candidates:
		var item: CanvasItem = candidate as CanvasItem
		if not is_instance_valid(item) or item.is_queued_for_deletion() or not item.is_visible_in_tree():
			continue
		var order: int = _draw_order(item)
		if top == null or order > top_order or (order == top_order and item.is_greater_than(top)):
			top = item
			top_order = order
	if top:
		for child: Node in top.find_children("*", "", true, false):
			if child is PixelDropdown and is_instance_valid(child._popup_panel) and child._popup_panel.is_visible_in_tree():
				return child._popup_panel
	return top


static func _draw_order(item: CanvasItem) -> int:
	var layer: CanvasLayer = item.get_canvas_layer_node()
	var order: int = (layer.layer if layer else 0) * 8192
	var current: CanvasItem = item
	while current:
		order += current.z_index
		if not current.z_as_relative:
			break
		current = current.get_parent() as CanvasItem
	return order


func _collect_interactive_controls(node: Node, out_targets: Array[Dictionary]) -> void:
	if node.is_queued_for_deletion() or (node is CanvasItem and not node.is_visible_in_tree()):
		return

	if (node is BaseButton and not node.disabled) or (node is Slider and node.editable):
		if node is Control and node.is_visible_in_tree():
			var rect: Rect2 = node.get_global_rect()
			if rect.size.x > 0 and rect.size.y > 0:
				out_targets.append({
					"type": &"button",
					"pos": rect.get_center(),
					"rect": rect,
					"node": node
				})
			return

	for child: Node in node.get_children():
		_collect_interactive_controls(child, out_targets)


func _collect_hand_dice(result: Array[Dictionary]) -> void:
	if Globals.player and Globals.player.dice_manager:
		for die: Dice in Globals.player.dice_manager.queue:
			if is_instance_valid(die) and die.is_visible_in_tree() and die.draggable.can_pick_up():
				var pos: Vector2 = die.global_position
				result.append({
					"type": &"die",
					"pos": pos,
					"rect": Rect2(-7, -7, 14, 14),
					"node": die
				})


func _collect_offer_targets(result: Array[Dictionary]) -> void:
	if is_instance_valid(Globals.reward_manager):
		_collect_offer_items(Globals.reward_manager, result)
	var shop: Node = get_tree().root.find_child("Shop", true, false)
	if shop is Shop and shop.is_open():
		_collect_offer_items(shop, result)
		_collect_interactive_controls(shop, result)
	var station: RepairStation = _get_repair_station()
	if station:
		_collect_interactive_controls(station, result)
		if Draggable.holding() and Draggable.holding().get_parent() is Tile:
			result.append({"type": &"sell_zone", "pos": station.sell_zone_centre(),
				"rect": Rect2(-12, -12, 24, 24), "node": station})


func _collect_offer_items(root: Node, result: Array[Dictionary]) -> void:
	if root is CanvasItem and not root.is_visible_in_tree():
		return
	if root is Reward and not root.can_take():
		return
	if root is Draggable:
		var item: Node2D = root.get_parent() as Node2D
		if item and root.can_pick_up() and not root.held_by_code and root != Draggable.holding():
			result.append({"type": &"offer", "pos": item.global_position,
				"rect": Rect2(-10, -10, 20, 20), "node": item})
		return
	for child: Node in root.get_children():
		_collect_offer_items(child, result)


func _get_repair_station() -> RepairStation:
	var station: RepairStation = get_tree().root.find_child("RepairStation", true, false) as RepairStation
	return station if station and station.is_visible_in_tree() else null


## Collect targets for Combat / Systems view
func _collect_combat_targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	_collect_hand_dice(result)
	_collect_offer_targets(result)

	# B. Tile Grid Slots
	if Globals.tile_grid and is_instance_valid(Globals.tile_grid) and Globals.tile_grid.is_visible_in_tree():
		var cells: Array[Vector2i] = Globals.tile_grid.get_cells()
		if Draggable.holding() and Draggable.holding().get_parent() is GridSlot:
			cells.append_array(Globals.tile_grid.get_locked_cells())
		for cell: Vector2i in cells:
			var pos: Vector2 = Globals.tile_grid.grid_to_global_pos(cell)
			var tile: Tile = Globals.tile_grid.tile_locations.get(cell)
			result.append({
				"type": &"tile_slot",
				"pos": pos,
				"rect": Rect2(-12, -12, 24, 24),
				"cell": cell,
				"node": tile,
				"grid": Globals.tile_grid
			})

	# C. Enemies
	if Globals.enemy_manager and is_instance_valid(Globals.enemy_manager):
		for enemy: Enemy in Globals.enemy_manager.get_alive_enemies():
			if is_instance_valid(enemy) and enemy.is_visible_in_tree():
				result.append({
					"type": &"enemy",
					"pos": enemy.global_position,
					"rect": Rect2(-20, -20, 40, 40),
					"node": enemy
				})

	# D. Targeting Computer Shift Arrows
	if Globals.targeting_computer and is_instance_valid(Globals.targeting_computer) and Globals.targeting_computer.is_visible_in_tree():
		for btn: TargetShiftButton in Globals.targeting_computer._shift_buttons():
			if is_instance_valid(btn) and btn.is_visible_in_tree() and btn.is_live():
				result.append({
					"type": &"button",
					"pos": btn.global_position,
					"rect": Rect2(-10, -10, 20, 20),
					"node": btn
				})

	# E. End Turn Button
	if Globals.player and is_instance_valid(Globals.player):
		var end_btn: Node = Globals.player.find_child("EndTurnButton", true, false)
		if end_btn is BaseButton and not end_btn.disabled and end_btn.is_visible_in_tree():
			var pos: Vector2 = end_btn.global_position
			result.append({
				"type": &"button",
				"pos": pos,
				"rect": Rect2(-24, -12, 48, 24),
				"node": end_btn
			})

	# F. Tab Buttons (Systems / Map)
	var main_viewer: Node = get_tree().root.find_child("MainViewer", true, false)
	if main_viewer and is_instance_valid(main_viewer):
		for tab_btn_name: String in ["SystemsButton", "MapButton"]:
			var btn: Node = main_viewer.find_child(tab_btn_name, true, false)
			if btn and btn is CanvasItem and btn.is_visible_in_tree():
				result.append({
					"type": &"button",
					"pos": btn.global_position,
					"rect": Rect2(-14, -8, 28, 16),
					"node": btn
				})

	return result


## Collect targets on Map
func _collect_map_targets(map_node: Map) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	_collect_hand_dice(result)
	_collect_offer_targets(result)

	# Arrow tiles on map
	for arrow_tile: Tile in [map_node.left_arrow_tile, map_node.right_arrow_tile]:
		if arrow_tile and is_instance_valid(arrow_tile) and arrow_tile.is_visible_in_tree():
			result.append({
				"type": &"tile_slot",
				"pos": arrow_tile.global_position,
				"rect": Rect2(-12, -12, 24, 24),
				"node": arrow_tile
			})

	# Tab Buttons
	var main_viewer: Node = get_tree().root.find_child("MainViewer", true, false)
	if main_viewer and is_instance_valid(main_viewer):
		for tab_btn_name: String in ["SystemsButton", "MapButton"]:
			var btn: Node = main_viewer.find_child(tab_btn_name, true, false)
			if btn and btn is CanvasItem and btn.is_visible_in_tree():
				result.append({
					"type": &"button",
					"pos": btn.global_position,
					"rect": Rect2(-14, -8, 28, 16),
					"node": btn
				})

	return result


func _get_active_map() -> Map:
	var tree: SceneTree = get_tree()
	if not tree:
		return null
	return tree.root.find_child("Map", true, false) as Map


## Steps focus in a direction
func _step(direction: int) -> void:
	_returning_die = null
	var current_node: Node = _current_target.get("node")
	var adjacent_tab: StringName = &""
	if is_instance_valid(current_node):
		if current_node.name == &"SystemsButton" and direction == Direction.RIGHT:
			adjacent_tab = &"MapButton"
		elif current_node.name == &"MapButton" and direction == Direction.LEFT:
			adjacent_tab = &"SystemsButton"
	for target: Dictionary in _targets:
		var node: Node = target.get("node")
		if adjacent_tab != &"" and is_instance_valid(node) and node.name == adjacent_tab:
			_set_target(target)
			return
	var slider: Slider = _current_target.get("node") as Slider
	if slider and slider.editable and direction in [Direction.LEFT, Direction.RIGHT]:
		var increment: float = slider.step if slider.step > 0.0 else (slider.max_value - slider.min_value) / 20.0
		slider.value += increment * (1.0 if direction == Direction.RIGHT else -1.0)
		return

	if _targets.is_empty():
		refresh()
	if _targets.is_empty():
		return

	# Special case: on dice, pressing UP jumps to the tile grid slot above
	if _current_target.get("type") == &"die" and direction == Direction.UP:
		_focus_best_grid_slot()
		return

	# Special case: on tile grid, navigating by grid coordinates
	if _current_target.get("type") == &"tile_slot" and _current_target.has("cell"):
		var cur_cell: Vector2i = _current_target.get("cell")
		var d_vec: Vector2i = Vector2i.ZERO
		match direction:
			Direction.UP: d_vec = Vector2i(0, -1)
			Direction.DOWN: d_vec = Vector2i(0, 1)
			Direction.LEFT: d_vec = Vector2i(-1, 0)
			Direction.RIGHT: d_vec = Vector2i(1, 0)

		var next_cell: Vector2i = cur_cell + d_vec
		var grid_target: Dictionary = _find_grid_slot_target(next_cell)
		if not grid_target.is_empty():
			_set_target(grid_target)
			_last_grid_cell = next_cell
			return
		elif direction == Direction.DOWN and not Draggable.holding():
			# Stepping down past the bottom of the grid when not holding a die moves to dice
			var die_target: Dictionary = _find_closest_target_of_type(&"die", _screen_of(_current_target))
			if not die_target.is_empty():
				_set_target(die_target)
				return

	# Standard spatial stepping: find closest candidate in the direction
	var origin: Vector2 = _screen_of(_current_target) if not _current_target.is_empty() else position
	var dir_vec: Vector2 = _direction_vector(direction)

	var best_target: Dictionary = {}
	var best_cost: float = INF

	for candidate: Dictionary in _targets:
		if _is_same_target(candidate, _current_target):
			continue
		var to: Vector2 = _screen_of(candidate) - origin
		var dist: float = to.length()
		if dist < 2.0:
			continue
		var norm: Vector2 = to / dist
		var dot: float = norm.dot(dir_vec)
		if dot < 0.2: # Must be forward in this direction
			continue

		var off_axis: float = 1.0 - dot
		var cost: float = dist + off_axis * dist * 2.5
		if cost < best_cost:
			best_cost = cost
			best_target = candidate

	if not best_target.is_empty():
		_set_target(best_target)
		if best_target.get("type") == &"tile_slot" and best_target.has("cell"):
			_last_grid_cell = best_target.get("cell")


## Focuses the best tile grid slot above current position or last used slot
func _focus_best_grid_slot() -> void:
	var map_node: Map = _get_active_map()
	if map_node and map_node.is_visible_in_tree():
		var arrow: Dictionary = _find_closest_target_of_type(&"tile_slot", position)
		if not arrow.is_empty():
			_set_target(arrow)
		return
	if not Globals.tile_grid:
		return

	# If last grid cell is still valid, use it
	if _last_grid_cell != Vector2i(-1, -1):
		var target: Dictionary = _find_grid_slot_target(_last_grid_cell)
		if not target.is_empty():
			_set_target(target)
			return

	# Otherwise find slot in the bottom row closest to the current X position
	var current_x: float = (_screen_of(_current_target) if not _current_target.is_empty() else position).x
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_dist_x: float = INF
	var max_y: int = -1

	for cell: Vector2i in Globals.tile_grid.get_cells():
		if cell.y > max_y:
			max_y = cell.y

	for cell: Vector2i in Globals.tile_grid.get_cells():
		if cell.y == max_y:
			var slot: Dictionary = _find_grid_slot_target(cell)
			if slot.is_empty():
				continue
			var dist_x: float = absf(_screen_of(slot).x - current_x)
			if dist_x < best_dist_x:
				best_dist_x = dist_x
				best_cell = cell

	if best_cell != Vector2i(-1, -1):
		var target: Dictionary = _find_grid_slot_target(best_cell)
		if not target.is_empty():
			_set_target(target)
			_last_grid_cell = best_cell


func _find_grid_slot_target(cell: Vector2i) -> Dictionary:
	for t in _targets:
		if t.get("type") == &"tile_slot" and t.get("cell") == cell:
			return t
	return {}


func _find_closest_target_of_type(type: StringName, from_pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var min_dist: float = INF
	for t in _targets:
		if t.get("type") == type:
			var dist: float = (_screen_of(t) - from_pos).length()
			if dist < min_dist:
				min_dist = dist
				best = t
	return best


func _set_target(target: Dictionary) -> void:
	var changed: bool = not _is_same_target(target, _current_target)
	var control: Control = target.get("node") as Control
	if changed and is_instance_valid(control):
		var ancestor: Node = control.get_parent()
		while ancestor:
			if ancestor is ScrollContainer:
				ancestor.ensure_control_visible(control)
			ancestor = ancestor.get_parent()
		_to_screen(target)
	var moved: bool = position.distance_to(_screen_of(target)) > 0.5
	_current_target = target
	position = _screen_of(target) if not target.is_empty() else position
	if _reticle_pos == Vector2.ZERO:
		_reticle_pos = position

	# Warp synthetic cursor so mouse hovers and engine events update
	if _cursor and InputManager.controller_active and (changed or moved):
		_cursor.focus_warp(position)

	if changed:
		focus_changed.emit(_current_target)


## A button: pick up die, drop die, click button, target enemy, or select waypoint
func _activate() -> void:
	if _current_target.is_empty():
		return

	var type: StringName = _current_target.get("type")
	var target_pos: Vector2 = _current_target.get("pos")
	var node: Node = _current_target.get("node")

	# Ensure pointer is warped to target
	if _cursor:
		_cursor.focus_warp(_screen_of(_current_target))

	# Finish a carry before treating the destination as another pickup.
	if Draggable.holding() and not is_instance_valid(_modal):
		var held_node: Node = Draggable.holding().get_parent()
		if held_node is Dice:
			_returning_die = weakref(held_node)
		if _cursor:
			_cursor.press_left(true)
			_cursor.press_left(false)
		await get_tree().process_frame
		refresh()
		return

	var pickup: Draggable = node.get_node_or_null("Draggable") as Draggable if is_instance_valid(node) else null
	if pickup and pickup.can_pick_up() and (type in [&"die", &"offer"] or (node is Tile and _get_repair_station())):
		pickup.begin_drag(target_pos, true)
		refresh()
		_focus_best_grid_slot()
		return

	# Case 3: Target enemy
	if type == &"enemy" and node is Enemy:
		var enemy: Enemy = node as Enemy
		if Globals.targeting_computer:
			Globals.targeting_computer.target_enemy(enemy)
		return

	# Case 4: Click button / slider / interactive node
	if node is BaseButton:
		if node.disabled:
			return
		if node.has_signal(&"pressed_within_window"):
			node.emit_signal(&"pressed_within_window")
		elif node.toggle_mode:
			node.button_pressed = not node.button_pressed
			node.pressed.emit()
		else:
			node.pressed.emit()
		return

	if node is TargetShiftButton:
		if node.is_live():
			node.press()
			node.pushed.emit()
		return

	if node and node.has_node("Clickable"):
		var clickable: Clickable = node.get_node("Clickable") as Clickable
		if clickable and clickable.input_pickable:
			clickable.clicked.emit()
		return

	if node is Clickable:
		node.clicked.emit()
		return

	# Fallback: synthetic left click
	if _cursor:
		_cursor.press_left(true)
		_cursor.press_left(false)


## B button: put back held die or cancel / close menu
func _cancel() -> void:
	if is_instance_valid(_modal):
		if _cursor:
			_cursor.cancel()
		return
	if Draggable.holding():
		var held_item: Draggable = Draggable.holding()
		if held_item.get_parent() is Dice:
			_returning_die = weakref(held_item.get_parent())
		held_item.put_back()
		# Re-focus the die that was put back
		await get_tree().process_frame
		refresh()
		return

	# Otherwise, back out of topmost screen
	if _cursor:
		_cursor.cancel()


## X button: Hotkey to show InfoShower on focused tile / object
func _show_info() -> void:
	if _current_target.is_empty() or is_instance_valid(_modal):
		return

	var node: Node = _current_target.get("node")
	if node is Tile:
		var tile: Tile = node as Tile
		if tile.clickable:
			tile.clickable.clicked.emit()
			return
		elif tile.has_method(&"_get_tile_info") and tile.sprite_frames != null:
			Events.show_info.emit(tile._get_tile_info())
			return

	if node and node.has_method(&"show_info"):
		node.show_info()
		return


func _is_same_target(a: Dictionary, b: Dictionary) -> bool:
	if a.get("type") != b.get("type"):
		return false
	if a.has("cell") and b.has("cell"):
		return a.get("cell") == b.get("cell")
	if a.has("node") and b.has("node"):
		return a.get("node") == b.get("node")
	return a.get("pos") == b.get("pos")


static func _direction_vector(dir: int) -> Vector2:
	match dir:
		Direction.UP: return Vector2.UP
		Direction.DOWN: return Vector2.DOWN
		Direction.LEFT: return Vector2.LEFT
		Direction.RIGHT: return Vector2.RIGHT
	return Vector2.ZERO
