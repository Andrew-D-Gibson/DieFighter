class_name Map
extends Node2D

@export_category('Game Data')
var scenario_list: Array[ScenarioResource]
var current_scenario_index: int

## The last tile Fate has corrupted, counting from the sector's left edge.
## -1 before it has taken any.
var fate_index: int
## How many tiles past fate_index Fate takes on the next jump.
var scenarios_in_danger: int
## Tiles past the danger zone that Fate has reached out and marked at random.
## Like the danger zone, they're corrupted on the next jump.
var stray_danger_indices: Array[int] = []

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
## What Fate leaves behind. Also the icon a corrupted tile shows, whichever
## variant it holds.
@export var fate_scenario: ScenarioResource
## Other encounters a corrupted tile can hold besides fate_scenario, so walking
## into Fate isn't always the same pushover. See _corrupt().
@export var fate_variants: Array[ScenarioResource] = []
## What a jump gate becomes once its boss is beaten: the same gate, with no one
## left guarding it.
@export var open_gate_scenario: ScenarioResource
@export var sprite_spacing: int = 14
## Chance, rolled per tile on every jump, that a tile past the danger zone
## starts corrupting anyway. Punishes a player who only watches the red zone.
@export_range(0.0, 1.0) var stray_danger_chance: float = 0.1

var scenario_sprites: Array[Sprite2D]
var _corrupted_sprite: Sprite2D
var _danger_sprite: Sprite2D
var _seam_sprite: Sprite2D
## The red blocks over stray tiles, apart from any that joined the danger zone.
var _stray_danger_sprites: Array[Sprite2D] = []
## Map-world x of the danger zone's right edge; its left edge is the seam.
var _danger_end_x: float
## Identifies the caption on screen, so it only re-animates when it changes.
var _shown_hint: Array = []
## Scenario icons with Fate spliced in, built on demand. See _danger_icon().
var _danger_icons: Dictionary[Texture2D, Texture2D] = {}

## Stands in for the Fate zones, which have no map icon of their own.
const _FATE_ICON: Texture2D = preload("res://Assets/Textures/Map/EncounterIcons/fate_encounter.png")
## Beside the caption while the jump gate is open: the way out is to the right.
const _NEXT_SECTOR_ICON: Texture2D = preload("res://Assets/Textures/Map/EncounterIcons/next_sector.png")
## How often the right arrow pulses while the gate is open, so the eye goes
## from "jump right" to the tile that does it.
const _GATE_PULSE_SECONDS: float = 1.1
## Animates a threatened icon on the map itself. Captions, which are too small
## and too brief to need it, use the static splice from _danger_icon().
const _CORRUPTING_SHADER: Shader = preload("res://Assets/Shaders/corrupting_icon.gdshader")
const _SEAM_SHADER: Shader = preload("res://Assets/Shaders/fate_seam.gdshader")
## The corrupted and danger zones each stop this far short of their shared
## border; the animated seam fills the gap. Leaves room for the wave to swing.
const _SEAM_HALF_WIDTH: int = 3
## Danger blocks with the dashed border on both sides, keyed by width in
## tiles, built from danger_area on first use. See _stray_danger_texture().
var _stray_danger_texs: Dictionary[int, Texture2D] = {}
var _seam_tex: Texture2D
## A jump plays out on the map while the drive spools up: Fate swallows what
## was in danger and the purple and red zones slide forward over it...
const _FATE_ADVANCE_TIME: float = 0.9
## ...then the next jump's danger spreads out: the red zone reaches over its
## new tiles, stray blocks fade in and their icons start corrupting.
const _DANGER_SPREAD_TIME: float = 0.7

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
## The jump's destination throbs, bigger and quicker than the player's own
## marker, so it reads as the target and not just another hovered icon.
const _TARGET_PULSE_SCALE: float = 1.5
const _TARGET_PULSE_TIME: float = 0.75
## How long the map lingers on the destination before the drive spools up.
const _JUMP_TARGET_HOLD_TIME: float = 1.0
const _JUMPING_TEXT: String = "Jumping..."
## True from the moment a jump is committed until the next scenario starts.
## The map is a progress display for the trip then, not something to browse.
var _jumping: bool = false
## Counts down to the right arrow's next pulse at an open gate.
var _gate_pulse_elapsed: float = 0.0
## The player's marker, and the breathing that keeps it easy to spot.
var _pip: Sprite2D
var _pip_tween: Tween
## What each map icon means to the player, keyed by texture file name: a
## title tinted to match the icon. Kept here rather than on ScenarioResource
## because the icon is what the player actually recognises, and several
## scenarios share one. One word each: the icon beside it does the rest.
var _icon_hints: Dictionary[String, Dictionary] = {
	"enemy_encounter.png": {"title": "Enemy", "color": Globals.red},
	"elite_encounter.png": {"title": "Elite", "color": Globals.purple},
	"unknown_encounter.png": {"title": "Unknown", "color": Globals.yellow},
	"shop.png": {"title": "Shop", "color": Globals.green},
	"healing_encounter.png": {"title": "Repair", "color": Globals.green},
	"empty_encounter.png": {"title": "Empty", "color": Globals.white.darkened(0.3)},
	"jump_gate.png": {"title": "Boss Gate", "color": Globals.blue},
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
		_jumping = false
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
	if not visible or scenario_list.is_empty() or _jumping:
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


func _process(delta: float) -> void:
	if not visible or scenario_list.is_empty() or _jumping:
		return
	var hovered: int = _hovered_scenario_index()
	_set_hovered(hovered)
	_set_hint(_compute_hint(hovered))
	_pulse_right_arrow_at_open_gate(delta)


func _pulse_right_arrow_at_open_gate(delta: float) -> void:
	if not Globals.jump_gate or not Globals.jump_gate.is_open() or not right_arrow_tile:
		_gate_pulse_elapsed = 0.0
		return
	_gate_pulse_elapsed -= delta
	if _gate_pulse_elapsed > 0.0:
		return
	_gate_pulse_elapsed = _GATE_PULSE_SECONDS
	right_arrow_tile.flash(Globals.yellow, 0.8, 0.5)


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
			return [_caption_icon(hovered), "Corrupting!", Globals.red]
		var entry: Dictionary = _icon_hints.get(texture.resource_path.get_file(), {})
		if entry.is_empty():
			return [texture, "Unknown", Globals.yellow]
		return [texture, entry.title, entry.color]

	if _mouse_in_map():
		var world: Vector2 = _mouse_world_position()
		if _danger_sprite and _danger_sprite.visible and _sprite_rect(_danger_sprite).has_point(world):
			return [_FATE_ICON, "Corrupting!", Globals.red]
		if _corrupted_sprite and _corrupted_sprite.texture and _sprite_rect(_corrupted_sprite).has_point(world):
			return [_FATE_ICON, "Corrupt", Globals.medium_purple]

	if Globals.jump_gate and Globals.jump_gate.is_open():
		return [_NEXT_SECTOR_ICON, tr("MAP_HINT_JUMP_RIGHT"), Globals.yellow]
	return [scenario_list.back().map_icon, "Gate ahead", Globals.blue]


## Whether Fate takes this scenario on the next jump. Mirrors jump(), which
## spares sector-gate scenarios.
func _is_in_danger(index: int) -> bool:
	if scenario_list[index].sector_gate_scenario:
		return false
	return index in stray_danger_indices or (
		index > fate_index and index <= fate_index + scenarios_in_danger
	)


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


## Each threatened icon gets its own material so its seed, and so its glitches,
## differ from its neighbours'.
func _corrupting_material(index: int) -> ShaderMaterial:
	var corrupting: ShaderMaterial = ShaderMaterial.new()
	corrupting.shader = _CORRUPTING_SHADER
	corrupting.set_shader_parameter("fate_texture", _FATE_ICON)
	corrupting.set_shader_parameter("seed", float(index) * 0.618)
	# Set even at its default: a uniform left unset isn't a property a jump
	# can tween. See _animate_fate_advance().
	corrupting.set_shader_parameter("progress", 0.5)
	return corrupting


## The icon a caption shows for a scenario: spliced with Fate if it's in danger,
## standing in for the animated shader the map sprite wears.
func _caption_icon(index: int) -> Texture2D:
	var texture: Texture2D = scenario_sprites[index].texture
	if _is_in_danger(index) and texture:
		return _danger_icon(texture)
	return texture


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
	# The left_ keys are from saves written while Fate could close in from both
	# ends.
	var state: Dictionary = game_save.map_state
	fate_index = state.get("fate_index", state.get("left_fate_index", 0))
	scenarios_in_danger = state.get("scenarios_in_danger", state.get("left_scenarios_in_danger", 0))
	stray_danger_indices.assign(game_save.map_state.get("stray_danger_indices", []))
	_update_map_sprites()


## Fate's progress through the sector, for the save. See _load_game_save().
func get_fate_state() -> Dictionary:
	return {
		"fate_index": fate_index,
		"scenarios_in_danger": scenarios_in_danger,
		"stray_danger_indices": stray_danger_indices.duplicate(),
	}


## Points the map at a whole new list of scenarios, resetting Fate's
## encroachment back to the sector edges. Used both when loading a save and
## when GameStateManager generates the next sector mid-run.
func load_sector(new_scenario_list: Array[ScenarioResource], start_index: int) -> void:
	scenario_list = new_scenario_list
	current_scenario_index = start_index
	
	# Fate starts just off the sector's left edge: nothing is corrupted yet,
	# only the first one or two tiles are under threat.
	fate_index = -1
	stray_danger_indices.clear()
	
	_pick_new_danger_ranges()
	
	# Mid-jump the map keeps showing the trip out of the old sector; arrival
	# redraws it (see start_scenario in _ready).
	if not _jumping:
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
	var fate_marker: Node2D = fate.instantiate()
	fate_marker.position = Vector2(-2 * sprite_spacing, 0)
	fate_marker.z_index = -1
	map_viewport.add_child(fate_marker)
	
	# Add the fate background sprite
	var fate_background: Sprite2D = Sprite2D.new()
	_corrupted_sprite = fate_background
	fate_background.texture = corrupted_area
	fate_background.position = Vector2(
		-232 + (sprite_spacing * (fate_index + 1)) - _SEAM_HALF_WIDTH, 4
	)

	fate_background.z_index = -2
	map_viewport.add_child(fate_background)
	
	
	# Show and move the danger area as needed. Stray tiles get the same red, so
	# red always means "corrupted on the next jump", wherever on the map it
	# shows up; each run of neighbouring red tiles is one block, so no border
	# splits them.
	var danger_runs: Array[Vector2i] = _danger_runs()
	var danger: Sprite2D = Sprite2D.new()
	_danger_sprite = danger
	danger.texture = danger_area
	danger.region_enabled = true
	danger.centered = false
	danger.position.y = -21
	danger.z_index = -2
	map_viewport.add_child(danger)

	var fate_border_x: float = _fate_border_x()
	_danger_end_x = _danger_zone_end_x(danger_runs)
	_set_danger_span(fate_border_x + _SEAM_HALF_WIDTH, _danger_end_x)

	_seam_sprite = _make_fate_seam(fate_border_x)
	map_viewport.add_child(_seam_sprite)

	_stray_danger_sprites.clear()
	for run: Vector2i in danger_runs:
		_add_stray_danger_sprite(run)
	
		
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
				scenario_sprite.material = _corrupting_material(i)
			
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
			_pip = scenario_sprite
			_pulse_pip(scenario_sprite)
		scenario_sprites.append(scenario_sprite)
		
	# Sync the slider to match the camera position
	_sync_slider_to_camera()


## The wavy, living border between the corrupted zone and the danger zone.
## Its tints are sampled from the zone textures so the seam always matches
## them; with nothing in danger, the right side is left clear.
func _make_fate_seam(border_x: float) -> Sprite2D:
	if not _seam_tex:
		var blank: Image = Image.create(
			_SEAM_HALF_WIDTH * 2, danger_area.get_height(), false, Image.FORMAT_RGBA8
		)
		blank.fill(Color.WHITE)
		_seam_tex = ImageTexture.create_from_image(blank)

	var seam_material: ShaderMaterial = ShaderMaterial.new()
	seam_material.shader = _SEAM_SHADER
	seam_material.set_shader_parameter("left_color", corrupted_area.get_image().get_pixel(0, 0))
	var right: Color = Color.TRANSPARENT
	if scenarios_in_danger > 0:
		right = danger_area.get_image().get_pixel(0, 0)
	seam_material.set_shader_parameter("right_color", right)

	var seam: Sprite2D = Sprite2D.new()
	seam.texture = _seam_tex
	seam.material = seam_material
	seam.centered = false
	seam.position = Vector2(border_x - _SEAM_HALF_WIDTH, -21)
	seam.z_index = -2
	return seam


## Where Fate's corrupted zone ends and its danger zone begins.
func _fate_border_x() -> float:
	return sprite_spacing * (fate_index + 0.5)


## Right edge of the danger zone: the run touching Fate, strays that join it
## included. Pops that run off danger_runs, leaving only the stray blocks.
## Nothing is in danger once Fate has stopped in front of the gate, which
## leaves the zone with no width.
func _danger_zone_end_x(danger_runs: Array[Vector2i]) -> float:
	if scenarios_in_danger <= 0:
		return _fate_border_x()
	var zone: Vector2i = danger_runs.pop_front()
	return sprite_spacing * (zone.y + 0.5)


## Stretches the danger zone between two map-world x positions. It shows the
## right end of danger_area, so the dashed border always marks its far edge.
func _set_danger_span(left_x: float, right_x: float) -> void:
	var width: int = maxi(roundi(right_x - left_x), 0)
	_danger_sprite.position.x = roundf(left_x)
	_danger_sprite.region_rect = Rect2(
		danger_area.get_width() - width, 0, width, danger_area.get_height()
	)
	_danger_sprite.visible = width > 0


func _add_stray_danger_sprite(run: Vector2i) -> Sprite2D:
	var stray_danger: Sprite2D = Sprite2D.new()
	stray_danger.texture = _stray_danger_texture(run.y - run.x + 1)
	stray_danger.centered = false
	stray_danger.position = Vector2(sprite_spacing * (run.x - 0.5), -21)
	stray_danger.z_index = -2
	map_viewport.add_child(stray_danger)
	_stray_danger_sprites.append(stray_danger)
	return stray_danger


## Every tile in danger, grouped into runs of neighbours as [first, last]
## scenario indices, left to right.
func _danger_runs() -> Array[Vector2i]:
	var runs: Array[Vector2i] = []
	for idx: int in range(fate_index + 1, len(scenario_list)):
		if not _is_in_danger(idx):
			continue
		if not runs.is_empty() and runs.back().y == idx - 1:
			runs[-1] = Vector2i(runs.back().x, idx)
		else:
			runs.append(Vector2i(idx, idx))
	return runs


## danger_area's border only ever needed to sit on the zone's right edge. A
## block of stray tiles wants it on both sides, so copy that edge onto the left.
func _stray_danger_texture(tile_count: int) -> Texture2D:
	if _stray_danger_texs.has(tile_count):
		return _stray_danger_texs[tile_count]

	var block: Image = Utils.slice_texture_right(danger_area, tile_count * sprite_spacing).get_image()
	block.decompress()
	var edge_x: int = block.get_width() - 1
	for y: int in range(block.get_height()):
		block.set_pixel(0, y, block.get_pixel(edge_x, y))
	_stray_danger_texs[tile_count] = ImageTexture.create_from_image(block)
	return _stray_danger_texs[tile_count]


## Keep the player's marker gently breathing so it's easy to spot.
func _pulse_pip(pip: Sprite2D) -> void:
	_pip_tween = pip.create_tween().set_loops()\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	_pip_tween.tween_property(pip, "scale", Vector2.ONE * _PIP_PULSE_SCALE, _PIP_PULSE_TIME)
	_pip_tween.tween_property(pip, "scale", Vector2.ONE, _PIP_PULSE_TIME)


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
	camera_movement_tween.tween_method(_set_camera_x, map_camera.position.x, \
		float(desired_camera_position), camera_tween_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	_pulse_target(scenario_sprites[index])
	await get_tree().create_timer(_JUMP_TARGET_HOLD_TIME).timeout


## Moves the camera and drags the view slider's knob along with it, so the
## knob glides in step with a camera tween instead of snapping at the end.
func _set_camera_x(x: float) -> void:
	map_camera.position = Vector2(x, 0)
	_sync_slider_to_camera()


## Sets the destination throbbing for the rest of the jump. The tween is the
## sprite's, so it ends when the map is rebuilt on arrival.
func _pulse_target(target: Sprite2D) -> void:
	var pulse: Tween = target.create_tween().set_loops()\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(target, "scale", Vector2.ONE * _TARGET_PULSE_SCALE, _TARGET_PULSE_TIME)
	pulse.tween_property(target, "scale", Vector2.ONE, _TARGET_PULSE_TIME)


## Freezes the map on the trip: no hover, no panning, and the caption says
## where the player is headed until they get there.
func _begin_jump_display(caption_icon: Texture2D) -> void:
	_jumping = true
	_panning = false
	_set_hovered(-1)
	_set_hint([caption_icon, _JUMPING_TEXT, Globals.blue])


## Going through the sector's gate, which the player is standing on: their own
## marker is the destination, and throbs like one.
func show_gate_jump() -> void:
	_begin_jump_display(scenario_list.back().map_icon)
	if is_instance_valid(_pip):
		if _pip_tween:
			_pip_tween.kill()
		_pulse_target(_pip)


## Marks the scenario at current_scenario_index as cleared — empty, or
## fate-infected if within an active danger range — mirroring what jump()
## does to the tile you're leaving. No-ops for sector-gate scenarios
## (boss fights, jump gates), which must never be overwritten.
func clear_current_scenario_slot() -> void:
	if scenario_list[current_scenario_index].sector_gate_scenario:
		return
	if current_scenario_index <= fate_index:
		_corrupt(current_scenario_index)
	else:
		scenario_list[current_scenario_index] = empty_scenario


## The player won the fight at the jump gate they're standing on. The gate stays
## a gate (never cleared, never corrupted) but nobody guards it now, so coming
## back to it later finds the ring waiting rather than the boss.
func open_current_gate() -> void:
	if scenario_list[current_scenario_index].sector_gate_scenario and open_gate_scenario:
		scenario_list[current_scenario_index] = open_gate_scenario


## Whether [param scenario] is one of Fate's: a tile it has already taken.
func is_fate_scenario(scenario: ScenarioResource) -> bool:
	return scenario != null and (scenario == fate_scenario or scenario in fate_variants)


## Hands the tile at [param idx] to Fate, as one of its encounters. The pick is
## a hash of the RUN stream's state and the tile rather than a draw from it,
## so adding variants leaves every seeded map (the tutorial's, AutoPilot
## transcripts) otherwise unchanged, the same way repair stations are placed.
func _corrupt(idx: int) -> void:
	if fate_variants.is_empty():
		scenario_list[idx] = fate_scenario
		return
	var pool: Array[ScenarioResource] = [fate_scenario]
	pool.append_array(fate_variants)
	var roll: int = hash([RNGManager.get_rng(RNGManager.Bucket.RUN).state, idx, "fate"])
	scenario_list[idx] = pool[posmod(roll, pool.size())]


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
		
	_begin_jump_display(_caption_icon(desired_scenario_index))
	await _tween_map_to_index(desired_scenario_index)

	# What the map shows now, for the animation to start from.
	var leaving_index: int = current_scenario_index
	var old_border_x: float = _fate_border_x()
	var taken: Array[int] = []
	for idx: int in range(fate_index + 1, len(scenario_list)):
		if _is_in_danger(idx):
			taken.append(idx)

	# Set the current index scenario to empty
	clear_current_scenario_slot()

	# Have "Fate" infect the scenarios in danger
	for idx: int in range(fate_index + 1, fate_index + 1 + scenarios_in_danger):
		if not scenario_list[idx].sector_gate_scenario:
			_corrupt(idx)
	for idx: int in stray_danger_indices:
		if not scenario_list[idx].sector_gate_scenario:
			_corrupt(idx)
			
	fate_index += scenarios_in_danger
	
	# Set up which scenarios are in danger next
	_pick_new_danger_ranges()
	_pick_stray_danger(desired_scenario_index)
	
	# Request a jump with the new index
	current_scenario_index = desired_scenario_index
	_animate_fate_advance(old_border_x, taken, [leaving_index, desired_scenario_index])
	request_jump_to_scenario.emit(scenario_list[current_scenario_index])
	

## Plays the jump's corruption on the map, which still shows the state from
## before it: Fate swallows the threatened icons as its zones slide forward,
## then the next jump's danger spreads out. Arrival rebuilds the map from the
## real state (see start_scenario in _ready), so this has to finish looking
## exactly like that rebuild. The tweens belong to the zone sprites, so a
## rebuild mid-animation cleanly stops them.
## [param taken]: the tiles that were in danger, now Fate's.
## [param pip_indices]: the tiles the player leaves and arrives at. Neither
## shows a scenario icon now, so neither starts corrupting here.
func _animate_fate_advance(old_border_x: float, taken: Array[int], pip_indices: Array[int]) -> void:
	if not is_instance_valid(_corrupted_sprite):
		return
	var new_border_x: float = _fate_border_x()
	var advance: float = new_border_x - old_border_x

	var swallow: Tween = _corrupted_sprite.create_tween().set_parallel()\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	swallow.tween_property(_corrupted_sprite, "position:x", _corrupted_sprite.position.x + advance, _FATE_ADVANCE_TIME)
	swallow.tween_property(_seam_sprite, "position:x", _seam_sprite.position.x + advance, _FATE_ADVANCE_TIME)
	# Purple eats into red from the left; red's far edge holds until it spreads.
	swallow.tween_method(
		func(left_x: float) -> void: _set_danger_span(left_x, _danger_end_x),
		old_border_x + _SEAM_HALF_WIDTH, new_border_x + _SEAM_HALF_WIDTH, _FATE_ADVANCE_TIME
	)
	for stray: Sprite2D in _stray_danger_sprites:
		swallow.tween_property(stray, "modulate:a", 0.0, _FATE_ADVANCE_TIME)

	var swallowed: Array[Sprite2D] = []
	for idx: int in taken:
		var icon: Sprite2D = scenario_sprites[idx]
		if icon.material is ShaderMaterial:
			swallowed.append(icon)
			swallow.tween_property(icon, "material:shader_parameter/progress", 1.0, _FATE_ADVANCE_TIME)

	await swallow.finished
	if not is_instance_valid(_corrupted_sprite):
		return

	for icon: Sprite2D in swallowed:
		icon.texture = fate_scenario.map_icon
		icon.material = null
	for stray: Sprite2D in _stray_danger_sprites:
		stray.queue_free()
	_stray_danger_sprites.clear()

	var danger_runs: Array[Vector2i] = _danger_runs()
	var old_end_x: float = maxf(_danger_end_x, new_border_x)
	_danger_end_x = _danger_zone_end_x(danger_runs)

	var spread: Tween = _corrupted_sprite.create_tween().set_parallel()\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	spread.tween_method(
		func(right_x: float) -> void: _set_danger_span(new_border_x + _SEAM_HALF_WIDTH, right_x),
		old_end_x, _danger_end_x, _DANGER_SPREAD_TIME
	)
	for run: Vector2i in danger_runs:
		var stray: Sprite2D = _add_stray_danger_sprite(run)
		stray.modulate.a = 0.0
		spread.tween_property(stray, "modulate:a", 1.0, _DANGER_SPREAD_TIME)

	for idx: int in range(fate_index + 1, len(scenario_list)):
		var icon: Sprite2D = scenario_sprites[idx]
		if idx in pip_indices or not _is_in_danger(idx) or not icon.texture:
			continue
		if not icon.material:
			icon.material = _corrupting_material(idx)
			icon.material.set_shader_parameter("progress", 0.0)
		spread.tween_property(icon, "material:shader_parameter/progress", 0.5, _DANGER_SPREAD_TIME)

	await spread.finished
	if is_instance_valid(_seam_sprite) and scenarios_in_danger <= 0:
		_seam_sprite.material.set_shader_parameter("right_color", Color.TRANSPARENT)


func _on_map_view_slider_value_changed(value: float) -> void:
	var desired_camera_position: int = _get_camera_position_from_slider_value(value)
	map_camera.position = Vector2(desired_camera_position, 0)


func _look_at_scenario_index(idx: int) -> void:
	var desired_camera_position: int = _get_camera_position_for_scenario(idx)
	map_camera.position = Vector2(desired_camera_position, 0)
	_sync_slider_to_camera()
	
	
func _pick_new_danger_ranges() -> void:
	# Usually 2. Fate stops one short of the last tile, the jump gate: the
	# player must always be able to leave the sector, so the gate is never
	# corrupted, never covered by the corrupted zone, and never in danger.
	var max_in_danger: int = mini(2, len(scenario_list) - fate_index - 2)

	if max_in_danger <= 0:
		scenarios_in_danger = 0
	else:
		scenarios_in_danger = RNGManager.randi_range(RNGManager.Bucket.RUN, 1, max_in_danger)


## Rolls stray_danger_chance for every tile past the danger zone. The tile the
## player is arriving at is spared — corrupting it underneath them would read
## as a bug, not a threat — as are the gate and tiles Fate already holds.
func _pick_stray_danger(arriving_index: int) -> void:
	stray_danger_indices.clear()
	for idx: int in range(fate_index + scenarios_in_danger + 1, len(scenario_list)):
		if idx == arriving_index \
		or scenario_list[idx].sector_gate_scenario \
		or is_fate_scenario(scenario_list[idx]):
			continue
		if RNGManager.randf(RNGManager.Bucket.RUN) < stray_danger_chance:
			stray_danger_indices.append(idx)
	
	
func disable_controls() -> void:
	left_arrow_tile.can_accept_dice.enabled = false
	right_arrow_tile.can_accept_dice.enabled = false
	
		
func enable_controls() -> void:
	left_arrow_tile.can_accept_dice.enabled = true
	right_arrow_tile.can_accept_dice.enabled = true


## Shows or hides the jump arrows outright. Disabling them still leaves two
## arrows on screen that look usable, which reads as a lock-out when the player
## isn't meant to be jumping at all yet (the tutorial's tour of the map).
func set_jump_arrows_visible(left_shown: bool, right_shown: bool) -> void:
	left_arrow_tile.visible = left_shown
	right_arrow_tile.visible = right_shown
