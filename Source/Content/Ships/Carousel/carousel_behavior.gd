class_name CarouselBehavior
extends Node2D
## The Carousel's rules: a tile grid that turns.
##
## The ship's cells are the 12 round the edge of a 5x3 rectangle (the ring)
## plus two fixed hub slots either side of the middle. The middle cell is a
## hole holding the Reactor, the ship's stand-in for the Engine Charger: a die
## there charges the engine by its value and is Fed up into the ignition slot,
## the ring cell above it, firing whatever tile is passing.
##
## Each player turn of a fight after the first, the ring steps one cell
## clockwise, carrying its tiles, before any turn-start response reads the
## board. A Gearbox can hold it still or run it backwards for a turn (tile
## data the Gearbox sets on itself, read and cleared here). The ring winds
## back to where the player left it when the fight ends, so the order they
## arrange out of combat is the order each fight opens with, and checkpoints
## (which are never taken mid-fight) always hold that arrangement.
##
## Lives as the TileGrid's "ShipBehavior" child, so it sits in grid space and
## hides with the grid on the map tab.

const RING: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
	Vector2i(4, 1), Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2), Vector2i(1, 2),
	Vector2i(0, 2), Vector2i(0, 1),
]
const HUB_SLOTS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(3, 1)]
const REACTOR_CELL: Vector2i = Vector2i(2, 1)
const IGNITION_CELL: Vector2i = Vector2i(2, 0)

## Tile data a Gearbox sets on itself; any tile carrying it steers next turn.
const HOLD_KEY: String = "ring_hold"
const REVERSE_KEY: String = "ring_reverse"
## Tile data counting the cells a tile has ridden since it last reset it
## (Slingshot reads it). Cleared between fights, like the Gearbox flags.
const STEPS_KEY: String = "ring_steps"

const _REACTOR: TileResource = preload("res://Source/Content/Ships/Carousel/reactor.tres")
const _CLUNK_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/tractor_lock.tres")
const _LAND_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/tile_dropped.tres")
## The cockpit in the Carousel's carnival reds and gold: the systems panel
## frame (same layout as MainViewer-Sheet.png), the engine gauge and the
## Reactor's exhaust rings.
const _VIEWER_SHEET: Texture2D = preload("res://Assets/Textures/Player/Carousel/carousel_viewer-Sheet.png")
const _GAUGE_FILL: Texture2D = preload("res://Assets/Textures/Player/Carousel/carousel_gauge_fill.png")
const _GAUGE_CHARGED: Texture2D = preload("res://Assets/Textures/Player/Carousel/carousel_gauge_charged.png")
const _ENGINE_RING: Texture2D = preload("res://Assets/Textures/Player/Carousel/carousel_engine_ring.png")

## One step's glide, after a short wind-up against the direction of travel.
const _WINDUP_SEC: float = 0.08
const _STEP_SEC: float = 0.26
## Per cell when the ring spins home after a fight.
const _HOME_STEP_SEC: float = 0.07

@export var track_lights: CarouselTrackLights
@export var track_panel: Sprite2D
## Shows next turn's motion in the socket the Engine Charger tile vacated.
@export var gear_indicator: Sprite2D

var _grid: TileGrid
var _reactor: Tile
var _modifier: ReactorIgnitionModifier
## Net cells the ring has turned this fight, clockwise positive.
var _ring_offset: int = 0
var _clunk_sfx: SoundEffectResource


func _ready() -> void:
	_grid = get_parent() as TileGrid
	_clunk_sfx = _CLUNK_SFX.duplicate()
	_clunk_sfx.pitch_scale = 0.7

	if track_lights:
		track_lights.ring = RING
		track_lights.ignition_cell = IGNITION_CELL
		track_lights.reactor_cell = REACTOR_CELL
		track_lights.cell_size = _grid.grid_spacing

	Events.player_turn_refresh.connect(_on_turn_refresh)
	Events.start_combat.connect(_on_fight_starts)
	Events.combat_finished.connect(_wind_home)
	Events.jump.connect(_wind_home)
	Events.start_scenario.connect(_arm_ignition)
	Events.first_turn_start.connect(_arm_ignition)
	Events.map_shown.connect(_set_reactor_shown.bind(false))
	Events.systems_shown.connect(_set_reactor_shown.bind(true))

	# The default sockets and the Engine Charger tile are other nodes' art and
	# not ready yet: dress the cockpit once the whole scene is up.
	_dress_cockpit.call_deferred()


func _process(_delta: float) -> void:
	var motion: int = pending_motion()
	if track_lights:
		track_lights.motion = motion
		track_lights.ignition_loaded = get_ignition_tile() != null
	if gear_indicator:
		gear_indicator.frame = 0 if motion > 0 else (1 if motion == 0 else 2)


## The Reactor tile (the Engine Charger's node, re-dressed), or null before
## the cockpit is set up.
func get_reactor() -> Tile:
	return _reactor


## Where a Feed from [param source] goes, when this ship's rules aim it rather
## than the chain's own targeting: the Reactor's goes to the ignition tile.
## Null for any other tile. The ignition modifier and the AutoPilot's
## forecast both ask this, so they agree on where the die ends up.
##
## A locked ignition tile only takes a die that would open its lock: a lock
## bounces any other die back to the hand, which would make the Reactor a
## free, endless charge pump.
func feed_target_for(source: Node, face: int) -> Tile:
	if source == null or source != _reactor:
		return null
	var ignition: Tile = get_ignition_tile()
	if ignition and ignition.is_locked_out() and not LockoutModifier.unlocks(face):
		return null
	return ignition


## The tile passing the ignition slot right now, if any.
func get_ignition_tile() -> Tile:
	var tile: Tile = _grid.tile_locations.get(IGNITION_CELL)
	return tile if is_instance_valid(tile) else null


## Which way the ring turns at the start of next turn: +1 clockwise, -1 back,
## 0 held. A hold beats a reverse when two Gearboxes disagree.
func pending_motion() -> int:
	var reverse: bool = false
	for tile: Tile in _grid.tile_locations.values():
		if not is_instance_valid(tile):
			continue
		if tile.effect_data.get(HOLD_KEY, 0) > 0:
			return 0
		if tile.effect_data.get(REVERSE_KEY, 0) > 0:
			reverse = true
	return -1 if reverse else 1


## Where the cell [param steps] cells round the ring from [param cell] is.
## Hub slots don't ride the ring and stay put.
static func ring_cell_after(cell: Vector2i, steps: int) -> Vector2i:
	var index: int = RING.find(cell)
	if index == -1:
		return cell
	return RING[posmod(index + steps, RING.size())]


## Sparks and a zap up the conduit as the Reactor fires the ignition slot
## (called by the ignition modifier as it aims the Feed).
func play_ignition(target: Tile) -> void:
	if track_lights:
		track_lights.flare_ignition()
	if not is_instance_valid(_reactor):
		return
	var to: Vector2 = _grid.grid_to_global_pos(IGNITION_CELL)
	Juice.zap(self, _reactor.global_position, to, Globals.yellow, 160)
	Juice.sparkle(self, to, Globals.yellow, 8 if target else 4, 30.0)
	if target:
		target.flash(Globals.yellow, 0.4, 0.25)


func _on_turn_refresh() -> void:
	if not _in_combat():
		return
	var motion: int = pending_motion()
	_clear_tile_data([HOLD_KEY, REVERSE_KEY])
	if motion == 0:
		_play_hold()
		return
	_turn_ring(motion, true)


func _on_fight_starts() -> void:
	_ring_offset = 0
	_clear_tile_data([HOLD_KEY, REVERSE_KEY, STEPS_KEY])


## Shifts every ring tile [param steps] cells round (clockwise positive).
## [param ridden] counts the move toward each tile's ring steps; the spin home
## after a fight doesn't.
func _turn_ring(steps: int, ridden: bool) -> void:
	var moves: Dictionary[Vector2i, Vector2i] = {}
	for cell: Vector2i in RING:
		if _grid.tile_locations.has(cell) and is_instance_valid(_grid.tile_locations[cell]):
			moves[cell] = ring_cell_after(cell, steps)
	_ring_offset = posmod(_ring_offset + steps, RING.size())
	if moves.is_empty():
		return

	var paths: Dictionary[Tile, Array] = {}
	for cell: Vector2i in moves:
		var tile: Tile = _grid.tile_locations[cell]
		var path: Array[Vector2] = []
		var step_sign: int = signi(steps)
		for k: int in range(1, absi(steps) + 1):
			path.append(_grid.grid_to_global_pos(ring_cell_after(cell, k * step_sign)))
		paths[tile] = path
		if ridden:
			tile.effect_data[STEPS_KEY] = tile.effect_data.get(STEPS_KEY, 0) + absi(steps)

	_grid.relocate_tiles(moves)
	_animate(paths, _STEP_SEC if absi(steps) == 1 else _HOME_STEP_SEC)


## When the fight is over (won, or fled through a jump), the ring winds back
## the short way round to where the player left it. Synchronous on the grid,
## so the after-combat checkpoint captures the arrangement, not the spin.
func _wind_home() -> void:
	_clear_tile_data([HOLD_KEY, REVERSE_KEY, STEPS_KEY])
	if _ring_offset == 0:
		return
	var back: int = -_ring_offset
	if _ring_offset > RING.size() / 2:
		back = RING.size() - _ring_offset
	_turn_ring(back, false)
	_ring_offset = 0


## Glides each tile along its path of cells: a little wind-up back against
## the track, a slide that overshoots and settles, then a clunk on landing.
func _animate(paths: Dictionary[Tile, Array], step_sec: float) -> void:
	Events.play_sound.emit(_clunk_sfx)
	if track_lights:
		track_lights.flare_track()
	for tile: Tile in paths:
		var path: Array = paths[tile]
		if path.is_empty() or not is_instance_valid(tile) or not tile.is_inside_tree():
			continue
		var draggable: Draggable = tile.draggable
		draggable.state = Draggable.DragState.MOVING_WITH_CODE
		var start: Vector2 = tile.global_position
		var first_dir: Vector2 = (Vector2(path[0]) - start).normalized()

		var tween: Tween = tile.create_tween()
		tween.tween_property(tile, "global_position", start - first_dir * 2.0, _WINDUP_SEC) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		for k: int in path.size():
			var last: bool = k == path.size() - 1
			var step: PropertyTweener = tween.tween_property(tile, "global_position", Vector2(path[k]), step_sec)
			if last:
				step.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			else:
				step.set_trans(Tween.TRANS_LINEAR)
		tween.tween_callback(_land.bind(tile))


func _land(tile: Tile) -> void:
	if not is_instance_valid(tile):
		return
	tile.draggable.state = Draggable.DragState.DEFAULT
	tile.global_position = tile.draggable.home_position
	Juice.bump(tile.sprite_frames, 0.12, 0.2)
	if _grid.find_tile_pos(tile) == IGNITION_CELL:
		tile.flash(Globals.yellow, 0.35, 0.3)
		Juice.sparkle(self, tile.global_position + Vector2(0, -10), Globals.yellow, 6, 25.0)
		Events.play_sound.emit(_LAND_SFX)


## The ring was held this turn: it judders against the brake instead.
func _play_hold() -> void:
	if track_lights:
		track_lights.flare_track()
	for cell: Vector2i in RING:
		var tile: Tile = _grid.tile_locations.get(cell)
		if is_instance_valid(tile):
			tile.shakeable.small_shake()
	Juice.callout_at(self, _grid.grid_to_global_pos(IGNITION_CELL) + Vector2(0, -8), "HOLD", Globals.red)


func _clear_tile_data(keys: Array[String]) -> void:
	for tile: Tile in _grid.tile_locations.values():
		if not is_instance_valid(tile):
			continue
		for key: String in keys:
			tile.effect_data.erase(key)


func _in_combat() -> bool:
	return Globals.state_manager != null \
		and Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT


## Puts the ignition modifier on this scenario's engine (each scenario builds
## a fresh one, and a jump's shutdown drops every modifier).
func _arm_ignition() -> void:
	var engine: ScenarioEngine = ScenarioEngine.current()
	if not engine or not is_instance_valid(_reactor):
		return
	if _modifier and engine.modifiers.has(_modifier):
		return
	_modifier = ReactorIgnitionModifier.new()
	_modifier.behavior = self
	engine.add_modifier(_modifier)


## Moves the Engine Charger's tile into the hub as the Reactor, lays the track
## art over the default sockets, and puts the gear indicator where the
## charger tile used to sit.
func _dress_cockpit() -> void:
	for cell: Vector2i in _grid.get_cells():
		var socket: Sprite2D = _grid.get_empty_cell_sprite(cell)
		if socket:
			socket.visible = false

	var charger: Node = get_tree().get_first_node_in_group(&"engine_charger")
	if charger:
		_reactor = charger.get_node_or_null(^"EngineChargerTile") as Tile
	# Nothing to re-dress outside the game scene (a test grid, say).
	if not _reactor:
		return
	if gear_indicator:
		gear_indicator.global_position = _reactor.global_position
	_reactor.tile_resource = _REACTOR
	var home: Vector2 = _grid.grid_to_global_pos(REACTOR_CELL)
	_reactor.global_position = home
	_reactor.draggable.home_position = home
	_set_reactor_shown(_grid.is_visible_in_tree())
	_arm_ignition()
	_paint_cockpit(charger)


## Repaints the shared cockpit art in the Carousel's colours. Swaps textures
## on the live nodes rather than editing their scenes, so other ships keep
## theirs.
func _paint_cockpit(charger: Node) -> void:
	var viewer: MainViewer = _grid.get_parent() as MainViewer
	if viewer and viewer.background and viewer.background.sprite_frames:
		var frames: SpriteFrames = viewer.background.sprite_frames.duplicate(true)
		for anim: StringName in frames.get_animation_names():
			for i: int in frames.get_frame_count(anim):
				var atlas: AtlasTexture = frames.get_frame_texture(anim, i) as AtlasTexture
				if atlas:
					atlas.atlas = _VIEWER_SHEET
		viewer.background.sprite_frames = frames
	var bar: TextureProgressBar = charger.get(&"progress_bar") as TextureProgressBar
	if bar:
		bar.texture_progress = _GAUGE_FILL
	var charged: Sprite2D = charger.get(&"charged_indicator") as Sprite2D
	if charged:
		charged.texture = _GAUGE_CHARGED
	var exhaust: GPUParticles2D = _reactor.get_node_or_null(^"ParticleMask/LargeEngineParticles") as GPUParticles2D
	if exhaust:
		exhaust.texture = _ENGINE_RING


## The Reactor belongs to the Engine Charger, not the grid, so it has to be
## hidden by hand when the map takes over the panel.
func _set_reactor_shown(shown: bool) -> void:
	if is_instance_valid(_reactor):
		_reactor.visible = shown
