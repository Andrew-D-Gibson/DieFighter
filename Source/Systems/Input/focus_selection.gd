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
##   "pos": Vector2 (viewport / global coordinates)
##   "rect": Rect2 (bounding box for reticle)
##   "node": Node (optional underlying node)
##   "cell": Vector2i (for tile slots)
var _current_target: Dictionary = {}
var _targets: Array[Dictionary] = []
var _last_grid_cell: Vector2i = Vector2i(-1, -1)

## Stick navigation timing
const STICK_DEADZONE: float = 0.5
const STICK_INITIAL_DELAY: float = 0.25
const STICK_REPEAT_RATE: float = 0.16
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
		var target_pos: Vector2 = _current_target.get("pos", Vector2.ZERO)
		var target_rect: Rect2 = _current_target.get("rect", Rect2(-12, -12, 24, 24))
		_reticle_pos = _reticle_pos.lerp(target_pos, clampf(delta * 25.0, 0.0, 1.0))
		_reticle_rect.size = _reticle_rect.size.lerp(target_rect.size, clampf(delta * 25.0, 0.0, 1.0))
		_reticle_rect.position = -_reticle_rect.size / 2.0
		_reticle_draw.queue_redraw()
	else:
		refresh()


func _on_reticle_draw() -> void:
	if _current_target.is_empty() or not active:
		return

	var center: Vector2 = _reticle_pos
	var size: Vector2 = _reticle_rect.size + Vector2(6, 6) # Slight padding
	var pulse: float = sin(_pulse_time * 7.0) * 1.5
	size += Vector2(pulse, pulse)

	var half: Vector2 = size / 2.0
	var top_left: Vector2 = center - half
	var bottom_right: Vector2 = center + half
	var bracket_len: float = clampf(minf(size.x, size.y) * 0.3, 4.0, 8.0)

	var line_color: Color = Color("#f4d03f") # Bright golden yellow accent
	var shadow_color: Color = Color("#000000", 0.7)
	var width: float = 2.0

	# Draw shadow brackets then colored brackets
	for pass_idx in 2:
		var c: Color = shadow_color if pass_idx == 0 else line_color
		var offset: Vector2 = Vector2(1, 1) if pass_idx == 0 else Vector2.ZERO
		var tl: Vector2 = top_left + offset
		var br: Vector2 = bottom_right + offset
		var tr: Vector2 = Vector2(br.x, tl.y)
		var bl: Vector2 = Vector2(tl.x, br.y)

		# Top-Left corner
		_reticle_draw.draw_line(tl, tl + Vector2(bracket_len, 0), c, width)
		_reticle_draw.draw_line(tl, tl + Vector2(0, bracket_len), c, width)

		# Top-Right corner
		_reticle_draw.draw_line(tr, tr - Vector2(bracket_len, 0), c, width)
		_reticle_draw.draw_line(tr, tr + Vector2(0, bracket_len), c, width)

		# Bottom-Left corner
		_reticle_draw.draw_line(bl, bl + Vector2(bracket_len, 0), c, width)
		_reticle_draw.draw_line(bl, bl - Vector2(0, bracket_len), c, width)

		# Bottom-Right corner
		_reticle_draw.draw_line(br, br - Vector2(bracket_len, 0), c, width)
		_reticle_draw.draw_line(br, br - Vector2(0, bracket_len), c, width)


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
	var result: Array[Dictionary] = []

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
					"rect": Rect2(-11, -11, 22, 22),
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
				"rect": Rect2(-12, -12, 24, 24),
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
			var die_target = _find_closest_target_of_type(&"die", _current_target.get("pos"))
			if not die_target.is_empty():
				_set_target(die_target)
				return

	# Standard spatial stepping: find closest candidate in the direction
	var origin: Vector2 = _current_target.get("pos", position)
	var dir_vec: Vector2 = _direction_vector(direction)

	var best_target: Dictionary = {}
	var best_cost: float = INF

	for candidate in _targets:
		if _is_same_target(candidate, _current_target):
			continue
		var to: Vector2 = candidate.get("pos") - origin
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
	var current_x: float = _current_target.get("pos", position).x
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_dist_x: float = INF
	var max_y: int = -1

	for cell in Globals.tile_grid.get_cells():
		if cell.y > max_y:
			max_y = cell.y

	for cell in Globals.tile_grid.get_cells():
		if cell.y == max_y:
			var cell_pos: Vector2 = Globals.tile_grid.grid_to_global_pos(cell)
			var dist_x: float = absf(cell_pos.x - current_x)
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
			var dist: float = (t.get("pos") - from_pos).length()
			if dist < min_dist:
				min_dist = dist
				best = t
	return best


func _set_target(target: Dictionary) -> void:
	_current_target = target
	position = target.get("pos", position)
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
		_cursor.focus_warp(target_pos)

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
