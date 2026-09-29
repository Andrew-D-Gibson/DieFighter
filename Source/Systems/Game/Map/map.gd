class_name Map
extends Node2D

@export_category('Game Data')
var scenario_list: Array[ScenarioResource]
var current_scenario_index: int

var left_fate_index: int
var right_fate_index: int
var left_scenarios_in_danger: int 
var right_scenarios_in_danger: int

@export_category('Map Textures')
@export var current_scenario_icon: Texture2D
@export var timeline_icon: Texture2D
@export var connector_sprite: Texture2D
@export var fate: PackedScene
@export var danger_area: Texture2D
@export var corrupted_area: Texture2D

@export_category('Components')
@export var map_viewport: SubViewport
@export var map_camera: Camera2D
@export var left_arrow_tile: Tile
@export var right_arrow_tile: Tile
## Caption above the map: what's under the cursor, or a nudge toward the gate.
@export var hint: MapHint

@export_category('Behavior')
@export var empty_scenario: ScenarioResource
@export var fate_scenario: ScenarioResource
@export var sprite_spacing: int = 14

var scenario_sprites: Array[Sprite2D]
var _corrupted_sprite: Sprite2D
var _danger_sprite: Sprite2D
## Identifies the caption on screen, so it only re-animates when it changes.
var _shown_hint: Array = []
## Scenario icons with Fate spliced in, built on demand. See _danger_icon().
var _danger_icons: Dictionary[Texture2D, Texture2D] = {}

## Stands in for the Fate zones, which have no map icon of their own.
const _FATE_ICON: Texture2D = preload("res://Assets/Textures/Map/EncounterIcons/fate_encounter.png")

## The player's marker breathes between these scales so it's easy to find.
const _PIP_PULSE_SCALE: float = 1.25
const _PIP_PULSE_TIME: float = 0.6
## A hovered location grows and drifts up and down while under the cursor.
const _HOVER_SCALE: float = 1.3
const _HOVER_BOB_HEIGHT: float = 1.0
const _HOVER_BOB_TIME: float = 0.4
var _hovered_index: int = -1
var _hover_rest_position: Vector2
var _hover_tweens: Array[Tween] = []
## What each map icon means to the player, keyed by texture file name: a
## title tinted to match the icon. Kept here rather than on ScenarioResource
## because the icon is what the player actually recognises, and several
## scenarios share one. One word each: the icon beside it does the rest.
var _icon_hints: Dictionary[String, Dictionary] = {
	"enemy_encounter.png": {"title": "Enemy", "color": Globals.red},
	"boss_encounter.png": {"title": "Boss", "color": Globals.purple},
	"unknown_encounter.png": {"title": "Unknown", "color": Globals.yellow},
	"shop.png": {"title": "Shop", "color": Globals.green},
	"empty_encounter.png": {"title": "Empty", "color": Globals.white.darkened(0.3)},
	"jump_gate.png": {"title": "Gate", "color": Globals.blue},
	"fate_encounter.png": {"title": "Corrupt", "color": Globals.medium_purple},
}

signal request_jump_to_scenario(scenario: ScenarioResource)

# Camera bounds constants
const MIN_CAMERA_INDEX: int = 2
const MAX_CAMERA_INDEX: int = 3

# Helper functions for camera positioning
##Returns min and max camera positions in world coordinates
func _get_camera_bounds() -> Dictionary:
	var min_pos: int = MIN_CAMERA_INDEX * sprite_spacing
	var max_pos: int = max((len(scenario_list) - MAX_CAMERA_INDEX) * sprite_spacing, min_pos)
	return {"min": min_pos, "max": max_pos}


##Get the camera position that centers on a specific scenario index
func _get_camera_position_for_scenario(scenario_index: int) -> int:
	var bounds: Dictionary = _get_camera_bounds()
	var desired_pos: int = scenario_index * sprite_spacing
	return clamp(desired_pos, bounds.min, bounds.max)


##Convert camera position to slider value (0.0 to 1.0)
func _get_slider_value_from_camera_position(camera_pos: int) -> float:
	var bounds: Dictionary = _get_camera_bounds()
	if bounds.max <= bounds.min:
		return 0.0
	return float(camera_pos - bounds.min) / float(bounds.max - bounds.min)


##Convert slider value (0.0 to 1.0) to camera position
func _get_camera_position_from_slider_value(slider_value: float) -> int:
	var bounds: Dictionary = _get_camera_bounds()
	return bounds.min + int((bounds.max - bounds.min) * slider_value)


## Camera travel per wheel notch (one scenario slot).
const _WHEEL_STEP: float = -6.0
## The map's on-screen area in local coordinates: the lower 50px of
## ViewportTexture, below the hint caption band. The Camera2D offset keeps
## map-world y=0 at this rect's centre.
const _MAP_RECT: Rect2 = Rect2(-73, -8, 120, 50)
var _panning: bool = false
var _pan_last_x: float = 0.0


func _ready() -> void:
	Globals.map = self
	
	Events.load_game_save.connect(_load_game_save)
	Events.start_scenario.connect(func() -> void:
		_update_map_sprites()
		_update_ui()
	)
	Events.engine_charge_changed.connect(_update_ui)
	
	# Initialize camera position and slider
	_initialize_camera_position()
	_update_ui()


## Click-drag inside the map, or use the wheel, to pan the camera. Handled
## here (unhandled) so the slider, tiles and dice get first claim on the mouse.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or scenario_list.is_empty():
		return

	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				if button.pressed:
					if not Globals.mouse_is_dragging_something and _mouse_in_map():
						_panning = true
						_pan_last_x = get_local_mouse_position().x
				else:
					_panning = false
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed and _mouse_in_map():
					_pan_camera_by(-_WHEEL_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed and _mouse_in_map():
					_pan_camera_by(_WHEEL_STEP)
	elif event is InputEventMouseMotion and _panning:
		var mouse_x: float = get_local_mouse_position().x
		# Dragging right pulls the map right, so the camera moves left.
		_pan_camera_by(_pan_last_x - mouse_x)
		_pan_last_x = mouse_x


func _process(_delta: float) -> void:
	if not visible or scenario_list.is_empty():
		return
	var hovered: int = _hovered_scenario_index()
	_set_hovered(hovered)
	_set_hint(_compute_hint(hovered))


## Index of the scenario icon under the cursor, or -1. The player's own
## marker doesn't count: it has its own pulse and needs no caption.
func _hovered_scenario_index() -> int:
	if not _mouse_in_map():
		return -1
	var world: Vector2 = _mouse_world_position()
	for i: int in range(scenario_sprites.size()):
		var icon: Sprite2D = scenario_sprites[i]
		if i != current_scenario_index and icon.texture and _sprite_rect(icon).has_point(world):
			return i
	return -1


## Map-viewport pixels are 1:1 with the TextureRect, centred on the camera.
func _mouse_world_position() -> Vector2:
	return map_camera.position + get_local_mouse_position() - _MAP_RECT.get_center()


## The caption as [icon, text, colour]. A hovered icon wins, then the
## purple/red zones; otherwise point at the gate.
func _compute_hint(hovered: int) -> Array:
	if hovered >= 0:
		var texture: Texture2D = scenario_sprites[hovered].texture
		if _is_in_danger(hovered):
			# The sprite already wears the spliced icon; see _update_map_sprites().
			return [texture, "Corrupting!", Globals.red]
		var entry: Dictionary = _icon_hints.get(texture.resource_path.get_file(), {})
		if entry.is_empty():
			return [texture, "Unknown", Globals.yellow]
		return [texture, entry.title, entry.color]

	if _mouse_in_map():
		var world: Vector2 = _mouse_world_position()
		if _danger_sprite and _danger_sprite.texture and _sprite_rect(_danger_sprite).has_point(world):
			return [_FATE_ICON, "Corrupting!", Globals.red]
		if _corrupted_sprite and _corrupted_sprite.texture and _sprite_rect(_corrupted_sprite).has_point(world):
			return [_FATE_ICON, "Corrupt", Globals.medium_purple]

	return [scenario_list.back().map_icon, "Gate ahead", Globals.blue]


## Whether Fate takes this scenario on the next jump. Mirrors jump(), which
## spares sector-gate scenarios.
func _is_in_danger(index: int) -> bool:
	return index > left_fate_index \
		and index <= left_fate_index + left_scenarios_in_danger \
		and not scenario_list[index].sector_gate_scenario


## The scenario's own icon with Fate's cut in diagonally from the left: what's
## there now, and what the next jump turns it into.
func _danger_icon(texture: Texture2D) -> Texture2D:
	if _danger_icons.has(texture):
		return _danger_icons[texture]

	var spliced: Image = texture.get_image()
	var fate_image: Image = _FATE_ICON.get_image()
	if spliced.get_size() != fate_image.get_size():
		return _FATE_ICON
	spliced.decompress()
	fate_image.decompress()
	spliced.convert(Image.FORMAT_RGBA8)
	fate_image.convert(Image.FORMAT_RGBA8)

	for y: int in range(spliced.get_height()):
		for x: int in range(spliced.get_width()):
			if x + y < spliced.get_width():
				spliced.set_pixel(x, y, fate_image.get_pixel(x, y))

	var result: ImageTexture = ImageTexture.create_from_image(spliced)
	_danger_icons[texture] = result
	return result


## Grow the hovered icon and set it bobbing; settle the previous one back.
func _set_hovered(index: int) -> void:
	if index == _hovered_index:
		return

	for tween: Tween in _hover_tweens:
		tween.kill()
	_hover_tweens.clear()

	if _hovered_index >= 0 and _hovered_index < scenario_sprites.size():
		var previous: Sprite2D = scenario_sprites[_hovered_index]
		var settle: Tween = previous.create_tween().set_parallel()
		settle.tween_property(previous, "scale", Vector2.ONE, 0.1)
		settle.tween_property(previous, "position", _hover_rest_position, 0.1)

	_hovered_index = index
	if index < 0:
		return

	var sprite: Sprite2D = scenario_sprites[index]
	_hover_rest_position = sprite.position

	var grow: Tween = sprite.create_tween()
	grow.tween_property(sprite, "scale", Vector2.ONE * _HOVER_SCALE, 0.12)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	var bob: Tween = sprite.create_tween().set_loops()\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(sprite, "position:y", _hover_rest_position.y - _HOVER_BOB_HEIGHT, _HOVER_BOB_TIME)
	bob.tween_property(sprite, "position:y", _hover_rest_position.y, _HOVER_BOB_TIME)

	_hover_tweens = [grow, bob]


## Bounds of a sprite in map-world space, honouring its centring and scale.
func _sprite_rect(sprite: Sprite2D) -> Rect2:
	var local: Rect2 = sprite.get_rect()
	return Rect2(sprite.position + local.position * sprite.scale, local.size * sprite.scale).abs()


func _set_hint(caption: Array) -> void:
	if caption == _shown_hint or not hint:
		return
	_shown_hint = caption
	hint.show_hint(caption[0], caption[1], caption[2])


func _mouse_in_map() -> bool:
	return _MAP_RECT.has_point(get_local_mouse_position())


func _pan_camera_by(delta_x: float) -> void:
	var bounds: Dictionary = _get_camera_bounds()
	map_camera.position.x = clampf(map_camera.position.x + delta_x, bounds.min, bounds.max)
	_sync_slider_to_camera()


## Initialize camera position and sync slider
func _initialize_camera_position() -> void:
	if len(scenario_list) == 0:
		return
	
	var camera_pos: int = _get_camera_position_for_scenario(current_scenario_index)
	map_camera.position = Vector2(camera_pos, 0)
	_sync_slider_to_camera()


## Sync the slider value to match the current camera position
func _sync_slider_to_camera() -> void:
	if len(scenario_list) == 0:
		return
	
	var slider_value: float = _get_slider_value_from_camera_position(int(map_camera.position.x))
	%MapViewSlider.set_value_no_signal(slider_value)
	
	
func _load_game_save(game_save: GameSaveResource) -> void:
	if game_save.map_state.is_empty():
		# A new run, or a save from before Fate's progress was recorded.
		load_sector(game_save.sector_scenarios, game_save.current_scenario_index)
		return

	# Restore rather than re-roll: load_sector() would reset Fate to the sector
	# edges and draw fresh danger ranges from the RUN stream, handing back the
	# ground Fate had already taken and shifting every roll after it.
	scenario_list = game_save.sector_scenarios
	current_scenario_index = game_save.current_scenario_index
	left_fate_index = game_save.map_state.get("left_fate_index", 0)
	right_fate_index = game_save.map_state.get("right_fate_index", len(scenario_list) - 1)
	left_scenarios_in_danger = game_save.map_state.get("left_scenarios_in_danger", 0)
	right_scenarios_in_danger = game_save.map_state.get("right_scenarios_in_danger", 0)
	_update_map_sprites()


## Fate's progress through the sector, for the save. See _load_game_save().
func get_fate_state() -> Dictionary:
	return {
		"left_fate_index": left_fate_index,
		"right_fate_index": right_fate_index,
		"left_scenarios_in_danger": left_scenarios_in_danger,
		"right_scenarios_in_danger": right_scenarios_in_danger,
	}


## Points the map at a whole new list of scenarios, resetting Fate's
## encroachment back to the sector edges. Used both when loading a save and
## when GameStateManager generates the next sector mid-run.
func load_sector(new_scenario_list: Array[ScenarioResource], start_index: int) -> void:
	scenario_list = new_scenario_list
	current_scenario_index = start_index
	
	left_fate_index = 0
	right_fate_index = len(scenario_list)-1
	
	_pick_new_danger_ranges()
	
	_update_map_sprites()
	
	
func _on_visibility_changed() -> void:
	_update_ui()
	
	
func _update_ui() -> void:
	if not Globals.player:
		return
	
	if Globals.player.is_engine_charged():
		left_arrow_tile.set_highlight(true)
		left_arrow_tile.set_gray_out(false)
		right_arrow_tile.set_highlight(true)
		right_arrow_tile.set_gray_out(false)
	else:
		left_arrow_tile.set_highlight(false)
		left_arrow_tile.set_gray_out(true)
		right_arrow_tile.set_highlight(false)
		right_arrow_tile.set_gray_out(true)


func _update_map_sprites() -> void:
	# Delete any old map, keeping the camera and the hint caption's layer
	for child: Node in map_viewport.get_children():
		if child is not Camera2D and child is not CanvasLayer:
			child.queue_free()
	scenario_sprites = []
	# The old sprites (and their hover tweens) go with the old map.
	_hovered_index = -1
	_hover_tweens.clear()
	
	# Shouldn't ever return here, but still
	if len(scenario_list) == 0:
		return
		
	# Add the fate sprite
	var left_fate: Node2D = fate.instantiate()
	left_fate.position = Vector2(-2 * sprite_spacing, 0)
	left_fate.z_index = -1
	map_viewport.add_child(left_fate)
	
	# Add the fate background sprite
	var left_fate_background: Sprite2D = Sprite2D.new()
	_corrupted_sprite = left_fate_background
	left_fate_background.texture = corrupted_area
	left_fate_background.position = Vector2(-232 + (sprite_spacing * (left_fate_index + 1)), 4)

	left_fate_background.z_index = -2
	map_viewport.add_child(left_fate_background)
	
	
	# Show and move the danger area as needed
	var left_danger: Sprite2D = Sprite2D.new()
	_danger_sprite = left_danger

	left_danger.texture = Utils.slice_texture_right(danger_area, left_scenarios_in_danger * sprite_spacing)
	left_danger.centered = false
	left_danger.position = Vector2((sprite_spacing * (left_fate_index + 0.5)), -21)

	left_danger.z_index = -2
	map_viewport.add_child(left_danger)
	
		
	for i: int in range(len(scenario_list)):
		# Create a timeline bar to the next location
		if i < len(scenario_list) - 1:
			var timeline_bar_sprite: Sprite2D = Sprite2D.new()
			timeline_bar_sprite.texture = timeline_icon
			timeline_bar_sprite.position = Vector2((i * sprite_spacing) + 7, 4)
			map_viewport.add_child(timeline_bar_sprite)
			
			
		# Add the sprite for this encounter
		var scenario_sprite: Sprite2D = Sprite2D.new()
		scenario_sprite.position = Vector2(i * sprite_spacing, 4)
		
		# Mark the encounter as either our present location or 
		# a possible destination with a map icon
		if current_scenario_index == i:
			scenario_sprite.texture = current_scenario_icon
			_look_at_scenario_index(i)
		else:
			scenario_sprite.texture = scenario_list[i].map_icon
			if _is_in_danger(i) and scenario_sprite.texture:
				scenario_sprite.texture = _danger_icon(scenario_sprite.texture)
			
			# Offset the icon up or down
			scenario_sprite.position += Vector2(0, -13 if i%2==0 else 13)
		
			# Add the connector sprite
			# Add the timeline connector sprite
			var timeline_connector_sprite: Sprite2D = Sprite2D.new()
			timeline_connector_sprite.position = Vector2(i * sprite_spacing, 0 if i%2==0 else 8)
			timeline_connector_sprite.texture = connector_sprite
			map_viewport.add_child(timeline_connector_sprite)
			
		map_viewport.add_child(scenario_sprite)
		if current_scenario_index == i:
			_pulse_pip(scenario_sprite)
		scenario_sprites.append(scenario_sprite)
		
	# Sync the slider to match the camera position
	_sync_slider_to_camera()


## Keep the player's marker gently breathing so it's easy to spot.
func _pulse_pip(pip: Sprite2D) -> void:
	var pulse: Tween = pip.create_tween().set_loops()\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(pip, "scale", Vector2.ONE * _PIP_PULSE_SCALE, _PIP_PULSE_TIME)
	pulse.tween_property(pip, "scale", Vector2.ONE, _PIP_PULSE_TIME)


func is_valid_destination(desired_scenario_index: int) -> bool:
	return len(scenario_list) > 0 and \
	desired_scenario_index >= 0 and \
	desired_scenario_index < len(scenario_list) and \
	desired_scenario_index != current_scenario_index
		
		
func _tween_map_to_index(index: int) -> void:
	# Calculate the desired camera position using helper function
	var desired_camera_position: int = _get_camera_position_for_scenario(index)
	
	# Tween the camera to center on the desired encounter
	var camera_tween_time: float = 0.5
	var camera_movement_tween: Tween = get_tree().create_tween()
	camera_movement_tween.tween_property(map_camera, 'position', \
		Vector2(desired_camera_position, 0), camera_tween_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	# Use the map's tween to animate the desired encounter's sprite
	# We use a singular tween to make sure only one tween is running at a time
	var tween_time: float = 1
	var scenario_zoom_tween: Tween = get_tree().create_tween()
	scenario_zoom_tween.tween_property(
		scenario_sprites[index], 
		'scale', 
		Vector2(1.5,1.5), 
		tween_time
	).from(Vector2(1,1))
	
	await scenario_zoom_tween.finished
	
	# Sync slider to match final camera position
	_sync_slider_to_camera()


## Marks the scenario at current_scenario_index as cleared — empty, or
## fate-infected if within an active danger range — mirroring what jump()
## does to the tile you're leaving. No-ops for sector-gate scenarios
## (boss fights, jump gates), which must never be overwritten.
func clear_current_scenario_slot() -> void:
	if scenario_list[current_scenario_index].sector_gate_scenario:
		return
	if current_scenario_index <= left_fate_index or current_scenario_index >= right_fate_index:
		scenario_list[current_scenario_index] = fate_scenario
	else:
		scenario_list[current_scenario_index] = empty_scenario


func jump(desired_scenario_index: int) -> void:
	# Bound the target scenarios to within the map
	# e.g. moving "off the map" just moves you to the farthest possible sector
	# This should never actually happen due to the tile implementation, 
	# but for safety it's here
	if desired_scenario_index < 0:
		desired_scenario_index = 0
	elif desired_scenario_index >= len(scenario_list):
		desired_scenario_index = len(scenario_list) - 1
		
	if not is_valid_destination(desired_scenario_index):
		printerr("Attempted to jump to an invalid destination: ", desired_scenario_index)
		return
		
	await _tween_map_to_index(desired_scenario_index)

	# Set the current index scenario to empty
	clear_current_scenario_slot()

	# Have "Fate" infect the scenarios in danger
	for idx: int in range(left_fate_index + 1, left_fate_index + 1 + left_scenarios_in_danger):
		if not scenario_list[idx].sector_gate_scenario:
			scenario_list[idx] = fate_scenario
			
	left_fate_index += left_scenarios_in_danger
	
	# Set up which scenarios are in danger next
	_pick_new_danger_ranges()
	
	# Request a jump with the new index
	current_scenario_index = desired_scenario_index
	request_jump_to_scenario.emit(scenario_list[current_scenario_index])
	

func _on_map_view_slider_value_changed(value: float) -> void:
	var desired_camera_position: int = _get_camera_position_from_slider_value(value)
	map_camera.position = Vector2(desired_camera_position, 0)


func _look_at_scenario_index(idx: int) -> void:
	var desired_camera_position: int = _get_camera_position_for_scenario(idx)
	map_camera.position = Vector2(desired_camera_position, 0)
	_sync_slider_to_camera()
	
	
func _pick_new_danger_ranges() -> void:
	# Handle the left-danger zone running into the right corrupted zone
	# This will usually be 2, except when the two danger zones close in on each other
	var max_left_scenarios_in_danger: int = min(2, len(scenario_list) - left_fate_index - 1)
	
	if max_left_scenarios_in_danger <= 0:
		left_scenarios_in_danger = 0
	else:
		left_scenarios_in_danger = RNGManager.randi_range(RNGManager.Bucket.RUN, 1, max_left_scenarios_in_danger)
	
	
func disable_controls() -> void:
	left_arrow_tile.can_accept_dice.enabled = false
	right_arrow_tile.can_accept_dice.enabled = false
	
		
func enable_controls() -> void:
	left_arrow_tile.can_accept_dice.enabled = true
	right_arrow_tile.can_accept_dice.enabled = true
