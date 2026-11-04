class_name CaravanFateEcho
extends Node
## Now and then a spilled echo, a fleet ship that fell into Fate and came
## back wrong, tears across the menu: it lurches between random points,
## surging nearer and falling away, twitching as it goes, and is gone again
## within a few seconds. Nothing in the caravan reacts; nobody wants to look.

@export var caravan: MenuCaravan
## The echoes that can turn up. Each one is drawn as it is in combat, facing
## the player.
@export var kinds: Array[CaravanShipKind]
## Seconds after the menu opens before the first echo, picked from this range.
@export var first_delay: Vector2 = Vector2(25.0, 45.0)
## Seconds between echoes after that.
@export var repeat_delay: Vector2 = Vector2(60.0, 120.0)
## How long an echo is on screen, picked from this range.
@export var duration: Vector2 = Vector2(3.0, 5.0)
## How many places it darts between on the way across, picked from this range.
@export var stops: Vector2i = Vector2i(3, 5)
## Where it darts to, in the caravan's space: the open sky between the menu
## buttons and the planet, clear of the title.
@export var arena: Rect2 = Rect2(100.0, 15.0, 190.0, 105.0)
## How big it gets at each stop, picked from this range, so it lunges at the
## player and falls back.
@export var depths: Vector2 = Vector2(0.5, 0.9)

@export_group("Twitch")
## Seconds between twitches.
@export var twitch_interval: float = 0.07
## How far a twitch throws it, in pixels.
@export var twitch_pixels: float = 1.0
## How often a twitch is a skip instead: the ship jumps, as if a frame of it
## went missing.
@export_range(0.0, 1.0) var skip_chance: float = 0.12
@export var skip_pixels: float = 4.0

@export_group("Look")
## The residue it sheds, newest first.
@export var trail_colors: PackedColorArray = PackedColorArray([
	Color("#C552F1"), Color("#A846CE"), Color("#80359D"), Color("#463C91")])
## Seconds between trail motes.
@export var trail_interval: float = 0.05

## How far off screen it starts and finishes, in pixels.
const _OFFSCREEN_MARGIN: float = 30.0
## Where its tendrils trail from, on its combat sprite: the top, where an
## ordinary ship has engines.
const _TAIL_POINT: Vector2 = Vector2(16, 4)
const _TRAIL_LENGTH: int = 8

enum Edge { LEFT, RIGHT, BOTTOM, TOP }


var _overlay: Node2D = Node2D.new()
## The echo while it's on screen.
var _echo: MenuCaravan.Ship
var _path: PackedVector2Array
var _path_depths: PackedFloat32Array
## When it reaches each point of [member _path], from 0 to 1.
var _arrivals: PackedFloat32Array
var _elapsed: float = 0.0
var _length: float = 0.0
var _twitch: Vector2 = Vector2.ZERO
var _twitch_timer: float = 0.0
var _trail: PackedVector2Array = []
var _trail_timer: float = 0.0


func _ready() -> void:
	if not caravan.is_node_ready():
		await caravan.ready
	caravan.add_overlay(_overlay)
	_overlay.draw.connect(_draw_overlay)
	_run()


func _process(delta: float) -> void:
	if _echo != null:
		_fly(delta)
	elif not _trail.is_empty():
		# What it left behind thins out after it's gone.
		_shed_trail(delta, false)
	_overlay.queue_redraw()


func _run() -> void:
	await _wait(_roll(first_delay))
	while true:
		await play()
		await _wait(_roll(repeat_delay))


## One echo, from the edge it bursts in at to the edge it leaves by.
func play() -> void:
	_plot_path()
	_length = _roll(duration)
	_elapsed = 0.0
	_echo = caravan.add_ship(RNGManager.pick_random(RNGManager.Bucket.COSMETIC, kinds),
		_path[0], _path_depths[0])
	_echo.beacon = MenuCaravan.Beacon.DARK
	await _wait(_length)
	caravan.remove_ship(_echo)
	_echo = null


## From an edge, through a few random stops, out by another edge.
func _plot_path() -> void:
	var entry: Edge = RNGManager.pick_random(RNGManager.Bucket.COSMETIC, Edge.values())
	var exits: Array = Edge.values().filter(func(edge: Edge) -> bool: return edge != entry)
	var exit: Edge = RNGManager.pick_random(RNGManager.Bucket.COSMETIC, exits)

	_path = PackedVector2Array([_offscreen_point(entry)])
	var stop_count: int = RNGManager.randi_range(RNGManager.Bucket.COSMETIC, stops.x, stops.y)
	for i: int in stop_count:
		_path.append(Vector2(
			RNGManager.randf_range(RNGManager.Bucket.COSMETIC, arena.position.x, arena.end.x),
			RNGManager.randf_range(RNGManager.Bucket.COSMETIC, arena.position.y, arena.end.y)))
	_path.append(_offscreen_point(exit))

	_path_depths = PackedFloat32Array()
	for i: int in _path.size():
		_path_depths.append(_roll(depths))

	# Uneven legs: some darts are quick, some drag.
	var weights: PackedFloat32Array = []
	var total: float = 0.0
	for i: int in _path.size() - 1:
		var weight: float = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.5, 1.5)
		weights.append(weight)
		total += weight
	_arrivals = PackedFloat32Array([0.0])
	for weight: float in weights:
		_arrivals.append(_arrivals[_arrivals.size() - 1] + weight / total)


func _offscreen_point(edge: Edge) -> Vector2:
	var screen: Vector2 = Vector2(JuicePixelated.BASE_RESOLUTION)
	var along: float = RNGManager.randf(RNGManager.Bucket.COSMETIC)
	match edge:
		Edge.LEFT:
			return Vector2(-_OFFSCREEN_MARGIN, lerpf(arena.position.y, arena.end.y, along))
		Edge.RIGHT:
			return Vector2(screen.x + _OFFSCREEN_MARGIN, lerpf(arena.position.y, arena.end.y, along))
		Edge.TOP:
			return Vector2(lerpf(arena.position.x, arena.end.x, along), -_OFFSCREEN_MARGIN)
		_:
			return Vector2(lerpf(arena.position.x, arena.end.x, along), screen.y + _OFFSCREEN_MARGIN)


func _fly(delta: float) -> void:
	_elapsed += delta
	var progress: float = clampf(_elapsed / _length, 0.0, 1.0)
	var leg: int = 0
	while leg < _arrivals.size() - 2 and progress > _arrivals[leg + 1]:
		leg += 1
	var span: float = _arrivals[leg + 1] - _arrivals[leg]
	var t: float = clampf((progress - _arrivals[leg]) / span, 0.0, 1.0)
	# Each dart starts and stops hard, so it seems to hang at every stop
	# before lunging at the next.
	t = smoothstep(0.0, 1.0, t)

	_twitch_timer -= delta
	if _twitch_timer <= 0.0:
		_twitch_timer = twitch_interval
		var reach: float = skip_pixels if RNGManager.randf(RNGManager.Bucket.COSMETIC) < skip_chance else twitch_pixels
		_twitch = Vector2(
			RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -reach, reach),
			RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -reach, reach)).round()

	_echo.position = (_spline(leg, t) + _twitch).round()
	_echo.depth = lerpf(_path_depths[leg], _path_depths[leg + 1], t)
	_shed_trail(delta, true)


## Catmull-Rom through the path, so it swings into each stop instead of
## turning on a point.
func _spline(leg: int, t: float) -> Vector2:
	var p0: Vector2 = _path[maxi(leg - 1, 0)]
	var p1: Vector2 = _path[leg]
	var p2: Vector2 = _path[leg + 1]
	var p3: Vector2 = _path[mini(leg + 2, _path.size() - 1)]
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 \
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3)


func _shed_trail(delta: float, shedding: bool) -> void:
	_trail_timer -= delta
	if _trail_timer > 0.0:
		return
	_trail_timer = trail_interval
	if shedding:
		_trail.insert(0, caravan.pixel_on(_echo, _TAIL_POINT))
	if _trail.size() > _TRAIL_LENGTH or not shedding:
		_trail.remove_at(_trail.size() - 1)


func _draw_overlay() -> void:
	# The newest mote still sits on the hull while the echo is flying.
	var first: int = 1 if _echo != null else 0
	for i: int in range(first, _trail.size()):
		var shade: int = mini(i * trail_colors.size() / _TRAIL_LENGTH, trail_colors.size() - 1)
		_overlay.draw_rect(Rect2(_trail[i], Vector2.ONE), trail_colors[shade])


func _wait(seconds: float) -> void:
	# A timer of our own, as in CaravanStraggler, so a menu that closes
	# mid-wait drops this coroutine instead of resuming it on a freed node.
	var timer: Timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.start(seconds)
	await timer.timeout
	timer.queue_free()


func _roll(range_values: Vector2) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, range_values.x, range_values.y)
