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
		return

	# Right stick can scroll the map in both schemes
	_update_right_stick_map(delta)

	if InputManager.control_scheme != InputBindings.ControlScheme.FOCUS:
		if _reticle_draw and _reticle_draw.visible:
			_reticle_draw.hide()
		return

	if not _reticle_draw.visible:
		_reticle_draw.show()

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
	var xf: Transform2D = _canvas_to_screen(ref)
	var rect: Rect2 = target.get("rect", Rect2(-12, -12, 24, 24))
	target["screen"] = xf * Vector2(target.get("pos", Vector2.ZERO))
	target["screen_rect"] = Rect2(rect.position * xf.get_scale(), rect.size * xf.get_scale())


## Handles controller buttons and d-pad events
func handle_event(event: InputEvent) -> bool:
	if not active or InputManager.control_scheme != InputBindings.ControlScheme.FOCUS:
		return false

	if event is InputEventJoypadButton:
		if not event.pressed or event.is_echo():
			return true

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
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
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
	if not map_node or not map_node.visible:
		return

	var rx: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(rx) > 0.2:
		var pan_speed: float = 300.0
		map_node._pan_camera_by(rx * pan_speed * delta)


## Rebuilds the target list and keeps or resets the focus
func refresh() -> void:
	_targets = _collect_targets()
	if _targets.is_empty():
		_current_target = {}
		return

	# If currently holding a die and not already on the tile grid, snap to the tile grid
	if Draggable.holding() and _current_target.get("type") != &"tile_slot":
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
	# 1. Menus / Popups take precedence
	var menu_targets: Array[Dictionary] = _collect_menu_targets()
	if not menu_targets.is_empty():
		return menu_targets

	# 2. Map Screen
	var map_node: Map = _get_active_map()
	if map_node and map_node.visible:
		return _collect_map_targets(map_node)

	# 3. Combat / Systems Screen
	return _collect_combat_targets()


## Collect targets for open menus / popups
func _collect_menu_targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var tree: SceneTree = get_tree()
	if not tree:
		return result

	var modal_nodes: Array[Node] = []
	# Check common menus
	for group_name in [&"modal_menu", &"options_menu", &"pause_menu"]:
		for n in tree.get_nodes_in_group(group_name):
			if n is CanvasItem and n.is_visible_in_tree():
				modal_nodes.append(n)

	# Direct lookup for options and pause menus if not grouped
	var options_menu = tree.root.find_child("OptionsMenu", true, false)
	if options_menu and options_menu is CanvasItem and options_menu.is_visible_in_tree():
		modal_nodes.append(options_menu)

	var pause_menu = tree.root.find_child("PauseMenu", true, false)
	if pause_menu and pause_menu is CanvasItem and pause_menu.is_visible_in_tree():
		modal_nodes.append(pause_menu)

	var confirm_dlg = tree.root.find_child("ConfirmDialog", true, false)
	if confirm_dlg and confirm_dlg is CanvasItem and confirm_dlg.is_visible_in_tree():
		modal_nodes.append(confirm_dlg)

	var codex_popup = tree.root.find_child("CodexPopup", true, false)
	if codex_popup and codex_popup is CanvasItem and codex_popup.is_visible_in_tree():
		modal_nodes.append(codex_popup)

	if modal_nodes.is_empty():
		return result

	var topmost: Node = modal_nodes.back()
	_collect_interactive_controls(topmost, result)
	return result


func _collect_interactive_controls(node: Node, out_targets: Array[Dictionary]) -> void:
	if node is CanvasItem and not node.is_visible_in_tree():
		return

	if node is BaseButton or node is HSlider or node is Slider:
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

	for child in node.get_children():
		_collect_interactive_controls(child, out_targets)


## Collect targets for Combat / Systems view
func _collect_combat_targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	# A. Dice in Hand
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

	# B. Tile Grid Slots
	if Globals.tile_grid and is_instance_valid(Globals.tile_grid) and Globals.tile_grid.is_visible_in_tree():
		for cell: Vector2i in Globals.tile_grid.get_cells():
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
			if is_instance_valid(btn) and btn.is_visible_in_tree():
				result.append({
					"type": &"button",
					"pos": btn.global_position,
					"rect": Rect2(-10, -10, 20, 20),
					"node": btn
				})

	# E. End Turn Button
	if Globals.player and is_instance_valid(Globals.player):
		var end_btn = Globals.player.find_child("EndTurnButton", true, false)
		if end_btn and end_btn is CanvasItem and end_btn.is_visible_in_tree():
			var pos: Vector2 = end_btn.global_position
			result.append({
				"type": &"button",
				"pos": pos,
				"rect": Rect2(-24, -12, 48, 24),
				"node": end_btn
			})

	# F. Tab Buttons (Systems / Map)
	var main_viewer = get_tree().root.find_child("MainViewer", true, false)
	if main_viewer and is_instance_valid(main_viewer):
		for tab_btn_name in ["SystemsButton", "MapButton"]:
			var btn = main_viewer.find_child(tab_btn_name, true, false)
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

	# Map Scenarios (Waypoints)
	for i: int in range(map_node.scenario_sprites.size()):
		var sprite: Sprite2D = map_node.scenario_sprites[i]
		if is_instance_valid(sprite) and sprite.is_visible_in_tree():
			result.append({
				"type": &"waypoint",
				"pos": sprite.global_position,
				"rect": Rect2(-7, -7, 14, 14),
				"node": sprite,
				"index": i,
				"map": map_node
			})

	# Map View Slider
	var slider: Control = map_node.find_child("MapViewSlider", true, false) as Control
	if slider and slider.is_visible_in_tree():
		var rect: Rect2 = slider.get_global_rect()
		result.append({
			"type": &"button",
			"pos": rect.get_center(),
			"rect": rect,
			"node": slider
		})

	# Arrow tiles on map
	for arrow_tile in [map_node.left_arrow_tile, map_node.right_arrow_tile]:
		if arrow_tile and is_instance_valid(arrow_tile) and arrow_tile.is_visible_in_tree():
			result.append({
				"type": &"tile_slot",
				"pos": arrow_tile.global_position,
				"rect": Rect2(-12, -12, 24, 24),
				"node": arrow_tile
			})

	# Tab Buttons
	var main_viewer = get_tree().root.find_child("MainViewer", true, false)
	if main_viewer and is_instance_valid(main_viewer):
		for tab_btn_name in ["SystemsButton", "MapButton"]:
			var btn = main_viewer.find_child(tab_btn_name, true, false)
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
			var die_target = _find_closest_target_of_type(&"die", _screen_of(_current_target))
			if not die_target.is_empty():
				_set_target(die_target)
				return

	# Standard spatial stepping: find closest candidate in the direction
	var origin: Vector2 = _screen_of(_current_target) if not _current_target.is_empty() else position
	var dir_vec: Vector2 = _direction_vector(direction)

	var best_target: Dictionary = {}
	var best_cost: float = INF

	for candidate in _targets:
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

	for cell in Globals.tile_grid.get_cells():
		if cell.y > max_y:
			max_y = cell.y

	for cell in Globals.tile_grid.get_cells():
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
	_current_target = target
	position = _screen_of(target) if not target.is_empty() else position
	if _reticle_pos == Vector2.ZERO:
		_reticle_pos = position

	# Warp synthetic cursor so mouse hovers and engine events update
	if _cursor:
		_cursor.focus_warp(position)

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

	# Case 1: Pick up die
	if type == &"die" and node is Dice:
		var die: Dice = node as Dice
		if die.draggable and die.draggable.can_pick_up():
			die.draggable.begin_drag(target_pos)
			# Transition focus to tile grid slot
			_focus_best_grid_slot()
			return

	# Case 2: Drop die onto tile slot
	if Draggable.holding():
		var held_item: Draggable = Draggable.holding()
		# Drop the carried item at current position
		if _cursor:
			_cursor.press_left(true)
			_cursor.press_left(false)
		# After dropping, re-focus to first die in hand
		await get_tree().process_frame
		refresh()
		var first_die = _find_closest_target_of_type(&"die", Vector2.ZERO)
		if not first_die.is_empty():
			_set_target(first_die)
		return

	# Case 3: Target enemy
	if type == &"enemy" and node is Enemy:
		var enemy: Enemy = node as Enemy
		if Globals.targeting_computer:
			Globals.targeting_computer.target_enemy(enemy)
		return

	# Case 4: Click button / slider / interactive node
	if node is BaseButton:
		node.emit_signal(&"pressed")
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
	if Draggable.holding():
		var held_item: Draggable = Draggable.holding()
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
	if _current_target.is_empty():
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
