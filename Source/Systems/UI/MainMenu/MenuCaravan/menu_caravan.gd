class_name MenuCaravan
extends Node2D
## A stretch of the Long Retreat drifting past the main menu. Caravan ships
## trail away from the player, sweep in front of the planet and loop round
## behind it, on toward the front of the fleet and away from Fate, which is
## behind the player. Now and then an Inbound pilgrim flies the other way.
## A ship can also be taken off the route and flown by hand (see
## CaravanStraggler), and other scenes can draw over the ships.
##
## Drawn into a viewport at the game's base resolution, like JuicePixelated,
## so ships keep whole pixels as they shrink into the distance. Each width a
## ship passes through is its own sprite, made by PixelArtShrinker.

## Where the caravan flies, starting nearest the player, in this node's space.
@export var route: Path2D
## How big ships are at each point of [member route], where 1 is their size
## in combat. Sizes are blended along the route between points.
@export var point_depths: PackedFloat32Array
## Ships are behind [member planet] from this point of [member route] on.
@export var behind_planet_from_point: int = 6
@export var planet: ColorRect
@export var kinds: Array[CaravanShipKind]

@export_group("Flow")
## Screen speed, in pixels per second, of a ship at combat size.
@export var speed: float = 8.0
## How much farther ships slow down. 1 is true perspective, which leaves the
## far end of the route nearly still; 0 moves everything at [member speed].
@export_range(0.0, 1.0) var perspective_slowdown: float = 0.7
## Seconds between ships joining the route, picked from this range.
@export var spawn_interval: Vector2 = Vector2(2.0, 7.5)
## How much faster or slower than [member speed] a ship can fly, so the gaps
## between ships open and close along the way.
@export_range(0.0, 0.5) var pace_variance: float = 0.05
## How far apart the flanks of the column are, in pixels, at combat size.
@export var column_width: float = 40.0
@export var sway_pixels: float = 1.5
## Simulated before the first frame, so the menu opens on a caravan that's
## already underway rather than on its first ship.
@export var prewarm_seconds: float = 300.0
## Ships fade out over this many pixels at the far end of the route.
@export var fade_distance: float = 30.0

@export_group("Look")
## Far ships fade toward this, the colour of the space around them.
@export var haze_color: Color = Color("#191347")
@export_range(0.0, 1.0) var max_haze: float = 0.4
## Narrower than this, a ship is only its lights.
@export var min_hull_width: int = 3
## Narrower than this, a ship's engines merge into one light.
@export var separate_engines_width: int = 12
## Narrower than this, a ship blinks its running light.
@export var beacon_width: int = 10
@export var beacon_period: float = 2.4
## The Mayday blink of a ship in trouble.
@export var distress_color: Color = Color("#F29C5D")
@export var distress_period: float = 0.7

const _BEHIND_PLANET_SHADER: Shader = preload("res://Source/Systems/UI/MainMenu/MenuCaravan/behind_planet.gdshader")
const _PREWARM_STEP: float = 0.25
const _BEACON_ON_SECONDS: float = 0.3

## What a ship's running light is doing.
enum Beacon { RUNNING, DISTRESS, DARK }


## One ship, on the route or flown by hand.
class Ship:
	var kind: CaravanShipKind
	## Centre on screen, in the caravan's space.
	var position: Vector2
	## How big it is, where 1 is its size in combat.
	var depth: float = 1.0
	## Faded out at the far end of the route.
	var fade: float = 1.0
	## False once taken off the route: then whoever took it moves it.
	var on_route: bool = true
	var engine_power: float = 1.0
	var beacon: Beacon = Beacon.RUNNING
	## How far along the route, in pixels.
	var distance: float
	## Toward the far end (1) or back toward the player (-1).
	var direction: float = 1.0
	## Across the column, from -1 to 1.
	var lane: float
	## Keeps ships from swaying and blinking in step.
	var phase: float
	## This ship's speed relative to [member MenuCaravan.speed].
	var pace: float = 1.0


var _ships: Array[Ship] = []
var _point_distances: PackedFloat32Array
var _behind_from: float
var _spawn_timer: float = 0.0
var _time: float = 0.0
## Shrunk sprites by kind and width.
var _sprites: Dictionary[String, ImageTexture] = {}

var _viewport: SubViewport = SubViewport.new()
var _behind_layer: Node2D = Node2D.new()
var _front_layer: Node2D = Node2D.new()


func _ready() -> void:
	assert(point_depths.size() == route.curve.point_count,
		"MenuCaravan needs one depth per route point")
	for i: int in route.curve.point_count:
		_point_distances.append(route.curve.get_closest_offset(route.curve.get_point_position(i)))
	_behind_from = _point_distances[behind_planet_from_point]

	_build_layers()
	var steps: int = ceili(prewarm_seconds / _PREWARM_STEP)
	for i: int in steps:
		_advance(_PREWARM_STEP)


func _process(delta: float) -> void:
	_advance(delta)
	_behind_layer.queue_redraw()
	_front_layer.queue_redraw()


## The ships still flying the route, farthest first.
func ships_on_route() -> Array[Ship]:
	return _ships.filter(func(ship: Ship) -> bool: return ship.on_route)


## Stops moving [param ship] along the route, leaving it where it is for the
## caller to fly. It's drawn in front of the planet from then on.
func take_off_route(ship: Ship) -> void:
	ship.on_route = false
	ship.fade = 1.0


## A ship of [param kind] that isn't on the route, for the caller to fly.
func add_ship(kind: CaravanShipKind, at: Vector2, depth: float) -> Ship:
	var ship: Ship = Ship.new()
	ship.kind = kind
	ship.position = at
	ship.depth = depth
	ship.on_route = false
	ship.phase = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.0, TAU)
	_ships.append(ship)
	return ship


func remove_ship(ship: Ship) -> void:
	_ships.erase(ship)


## Draws [param node] over the ships, in the same pixels and space.
func add_overlay(node: Node2D) -> void:
	_viewport.add_child(node)


## Where a pixel of [param ship]'s combat sprite, [param texture_point], is
## on screen right now, in the caravan's space.
func pixel_on(ship: Ship, texture_point: Vector2) -> Vector2:
	var full_size: Vector2 = ship.kind.texture.get_size()
	var scale_factor: float = _width_of(ship) / full_size.x
	var placed: Vector2 = texture_point
	if _drawn_flipped(ship.kind):
		placed.y = full_size.y - 1.0 - placed.y
	return _top_left_of(ship) + (placed * scale_factor).floor()


func _build_layers() -> void:
	_viewport.size = JuicePixelated.BASE_RESOLUTION
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)

	var occluder: ShaderMaterial = ShaderMaterial.new()
	occluder.shader = _BEHIND_PLANET_SHADER
	var planet_material: ShaderMaterial = planet.material as ShaderMaterial
	var center: Vector2 = to_local(planet.get_global_transform() * (planet.size / 2.0))
	occluder.set_shader_parameter("planet_center", center)
	occluder.set_shader_parameter("planet_radius",
		float(planet_material.get_shader_parameter("surface_radius")) * planet.size.x)
	_behind_layer.material = occluder

	# Far side first, so the planet's near side and its ships cover it.
	_viewport.add_child(_behind_layer)
	_viewport.add_child(_front_layer)
	_behind_layer.draw.connect(_draw_layer.bind(_behind_layer, true))
	_front_layer.draw.connect(_draw_layer.bind(_front_layer, false))

	var display: Sprite2D = Sprite2D.new()
	display.centered = false
	display.texture = _viewport.get_texture()
	# A transparent viewport stores its colours premultiplied by alpha (see
	# JuicePixelated), and fading ships are half transparent.
	var blend: CanvasItemMaterial = CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	display.material = blend
	add_child(display)


func _advance(delta: float) -> void:
	_time += delta
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn()
		_spawn_timer = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, spawn_interval.x, spawn_interval.y)

	var length: float = route.curve.get_baked_length()
	for ship: Ship in _ships:
		if not ship.on_route:
			continue
		ship.distance += ship.direction * ship.pace * speed * pow(_depth_at(ship.distance), perspective_slowdown) * delta
		ship.depth = _depth_at(ship.distance)
		ship.position = _route_position_of(ship)
		ship.fade = smoothstep(0.0, fade_distance, ship.distance) * smoothstep(0.0, fade_distance, length - ship.distance)
	_ships = _ships.filter(func(ship: Ship) -> bool:
		return not ship.on_route or (ship.distance >= 0.0 and ship.distance <= length))
	# Farthest first, so nearer ships draw over them.
	_ships.sort_custom(func(a: Ship, b: Ship) -> bool: return a.depth < b.depth)


func _spawn() -> void:
	var ship: Ship = Ship.new()
	ship.kind = _pick_kind()
	ship.direction = -1.0 if ship.kind.flies_toward_fate else 1.0
	ship.distance = route.curve.get_baked_length() if ship.kind.flies_toward_fate else 0.0
	ship.lane = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, ship.kind.lane_range.x, ship.kind.lane_range.y)
	if ship.kind.either_flank and RNGManager.randf(RNGManager.Bucket.COSMETIC) < 0.5:
		ship.lane = -ship.lane
	ship.phase = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.0, TAU)
	ship.pace = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 1.0 - pace_variance, 1.0 + pace_variance)
	_ships.append(ship)


func _pick_kind() -> CaravanShipKind:
	var total: float = 0.0
	for kind: CaravanShipKind in kinds:
		total += kind.weight
	var roll: float = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.0, total)
	for kind: CaravanShipKind in kinds:
		roll -= kind.weight
		if roll <= 0.0:
			return kind
	return kinds.back()


## How big ships are [param distance] pixels along the route.
func _depth_at(distance: float) -> float:
	for i: int in range(1, _point_distances.size()):
		if distance <= _point_distances[i]:
			var span: float = _point_distances[i] - _point_distances[i - 1]
			var t: float = 0.0 if span <= 0.0 else (distance - _point_distances[i - 1]) / span
			return lerpf(point_depths[i - 1], point_depths[i], clampf(t, 0.0, 1.0))
	return point_depths[point_depths.size() - 1]


## Where on screen [param ship] is centred, in this node's space.
func _route_position_of(ship: Ship) -> Vector2:
	var curve: Curve2D = route.curve
	var on_route: Vector2 = curve.sample_baked(ship.distance)
	var tangent: Vector2 = curve.sample_baked(ship.distance + 2.0) - curve.sample_baked(ship.distance - 2.0)
	var across: Vector2 = tangent.normalized().orthogonal()
	var sway: Vector2 = Vector2(sin(_time * 0.35 + ship.phase), sin(_time * 0.27 + ship.phase * 1.7))
	var offset: Vector2 = across * ship.lane * column_width * 0.5 + sway * sway_pixels
	return route.transform * (on_route + offset * ship.depth)


func _draw_layer(layer: Node2D, behind: bool) -> void:
	for ship: Ship in _ships:
		if (ship.on_route and ship.distance >= _behind_from) == behind:
			_draw_ship(layer, ship)


func _draw_ship(layer: Node2D, ship: Ship) -> void:
	var width: int = _width_of(ship)
	var top_left: Vector2 = _top_left_of(ship)
	var size: Vector2 = _size_of(ship)
	if width >= min_hull_width:
		var haze: float = max_haze * clampf(1.0 - ship.depth, 0.0, 1.0)
		var tint: Color = Color.WHITE.lerp(haze_color, haze)
		tint.a = ship.fade
		layer.draw_texture(_sprite_for(ship.kind, width), top_left, tint)

	var light_strength: float = ship.fade * lerpf(0.6, 1.0, clampf(ship.depth * 3.0, 0.0, 1.0))
	var center: Vector2 = (top_left + size / 2.0).floor()
	var engines: PackedVector2Array = []
	for engine: Vector2 in ship.kind.engine_points:
		engines.append(pixel_on(ship, engine) if width >= min_hull_width else center)
	if width < separate_engines_width and not engines.is_empty():
		var sum: Vector2 = Vector2.ZERO
		for engine: Vector2 in engines:
			sum += engine
		engines = PackedVector2Array([(sum / engines.size()).floor()])
	var pulse: float = 0.85 + 0.15 * sin(_time * 3.0 + ship.phase)
	for engine: Vector2 in engines:
		_draw_light(layer, engine, ship.kind.engine_color, light_strength * pulse * ship.engine_power)

	# The nose: the top of a ship drawn flying away, the bottom of one coming back.
	var nose_offset: float = floorf(size.y / 2.0)
	var nose: Vector2 = center + Vector2(0, -nose_offset if _drawn_flipped(ship.kind) else nose_offset)
	match ship.beacon:
		Beacon.RUNNING:
			var blinking: bool = fmod(_time + ship.phase, beacon_period) < _BEACON_ON_SECONDS
			if width < beacon_width and (blinking or ship.kind.flies_toward_fate):
				_draw_light(layer, nose, ship.kind.beacon_color, light_strength)
		Beacon.DISTRESS:
			# At every size: a Mayday is meant to be seen.
			if fmod(_time + ship.phase, distress_period) < distress_period * 0.5:
				_draw_light(layer, nose, distress_color, 1.0)


func _draw_light(layer: Node2D, at: Vector2, color: Color, strength: float) -> void:
	var lit: Color = color
	lit.a *= strength
	layer.draw_rect(Rect2(at, Vector2.ONE), lit)


func _width_of(ship: Ship) -> int:
	var full_width: int = int(ship.kind.texture.get_width())
	return clampi(roundi(full_width * ship.depth), 1, full_width)


func _size_of(ship: Ship) -> Vector2:
	var full_size: Vector2 = ship.kind.texture.get_size()
	return (full_size * (float(_width_of(ship)) / full_size.x)).round().max(Vector2.ONE)


func _top_left_of(ship: Ship) -> Vector2:
	return (ship.position - _size_of(ship) / 2.0).round()


## Ships flying away are drawn upside down: nose to the front of the fleet,
## engines toward the player.
func _drawn_flipped(kind: CaravanShipKind) -> bool:
	return not kind.flies_toward_fate


func _sprite_for(kind: CaravanShipKind, width: int) -> ImageTexture:
	var key: String = "%d:%d" % [kind.get_instance_id(), width]
	if not _sprites.has(key):
		var image: Image = PixelArtShrinker.shrink(kind.texture.get_image(), width, _drawn_flipped(kind))
		_sprites[key] = ImageTexture.create_from_image(image)
	return _sprites[key]
