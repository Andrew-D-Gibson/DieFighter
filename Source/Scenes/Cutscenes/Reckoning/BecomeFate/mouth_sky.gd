extends Node2D
## The sky through the hole's mouth, seen from inside (RECKONING_ENDINGS.md
## §6.5, Become Fate): what makes "we're looking out of the hole" readable.
##
## Two things give it away, both the opening's own physics turned round:
## - The stars bend at the edge. Far from the rim they hold still; near it
##   they're dragged round with the hole and smeared into arcs along the rim,
##   longer the nearer they are, the way light bends round a black hole.
## - Everything falls toward us. Scrap and Fate's shards come up out of the
##   distance in the middle, grow as they near, speed up, swing round with
##   the rim and are gone over its edge: the opening's debris, dragged into
##   Fate, seen from Fate's side.
##
## Drawn a whole art pixel at a time round this node's origin, the middle of
## the mouth, so it sits on the 320x180 grid.

## The mouth's radius in art pixels: nothing is drawn past it.
@export var radius: float = 80.0
@export var num_of_stars: int = 120
## Extra stars crowded into the band just inside the rim: light from behind
## the hole, bent round it into a ring.
@export var num_of_ring_stars: int = 50
@export var num_of_motes: int = 26
## How fast the sky at the rim wheels round, in radians per second. The
## middle of the sky never moves.
@export var drag: float = 0.22
## Radians the whole picture is turned by: the camera turning round.
var turn: float = 0.0
## How many motes are falling, 0-1 of num_of_motes. The rest wait.
var fall: float = 1.0

## Approved palette.
const _STAR: Color = Color("#cef0f1")
const _SCRAP: Array[Color] = [Color("#8e8b85"), Color("#636057"), Color("#a5a29d")]
const _SHARDS: Array[Color] = [Color("#80359d"), Color("#463c91"), Color("#a846ce")]
## How long a star near the rim is smeared, in art pixels.
const _MAX_ARC: float = 14.0

## Per star: its distance out as a fraction of the radius, its angle and how
## bright it is.
var _star_reach: PackedFloat32Array = PackedFloat32Array()
var _star_angle: PackedFloat32Array = PackedFloat32Array()
var _star_alpha: PackedFloat32Array = PackedFloat32Array()
## Per mote: distance out (0-1 of the radius), angle, speed, colour and
## whether it's waiting to start.
var _mote_reach: PackedFloat32Array = PackedFloat32Array()
var _mote_angle: PackedFloat32Array = PackedFloat32Array()
var _mote_speed: PackedFloat32Array = PackedFloat32Array()
var _mote_color: PackedColorArray = PackedColorArray()
var _age: float = 0.0


func _ready() -> void:
	for i: int in num_of_stars:
		# Square root: spread evenly over the disc rather than bunched in the
		# middle.
		_star_reach.append(sqrt(_randf(0.0, 1.0)) * 0.985)
		_star_angle.append(_randf(0.0, TAU))
		_star_alpha.append(_randf(0.25, 0.85))
	for i: int in num_of_ring_stars:
		_star_reach.append(_randf(0.86, 0.985))
		_star_angle.append(_randf(0.0, TAU))
		_star_alpha.append(_randf(0.3, 0.7))
	for i: int in num_of_motes:
		_mote_reach.append(_randf(0.0, 1.0))
		_mote_angle.append(_randf(0.0, TAU))
		_mote_speed.append(_randf(0.05, 0.12))
		var shard: bool = _randf(0.0, 1.0) < 0.45
		var palette: Array[Color] = _SHARDS if shard else _SCRAP
		_mote_color.append(palette[int(_randf(0.0, palette.size() - 0.01))])


func _process(delta: float) -> void:
	_age += delta
	for i: int in _mote_reach.size():
		var reach: float = _mote_reach[i]
		# Falls faster the nearer it gets: the pull, and the nearness.
		reach += (_mote_speed[i] + reach * reach * 0.9) * delta
		_mote_angle[i] += _swirl(reach) * delta
		if reach >= 1.0:
			reach = _randf(0.0, 0.08)
			_mote_angle[i] = _randf(0.0, TAU)
		_mote_reach[i] = reach
	queue_redraw()


func _draw() -> void:
	for i: int in _star_reach.size():
		var reach: float = _star_reach[i]
		var angle: float = _star_angle[i] + turn + _age * drag * _rim_weight(reach)
		var lit: float = _star_alpha[i] * lerpf(1.0, 1.6, _rim_weight(reach))
		_draw_arc_pixels(reach * radius, angle, 1.0 + _MAX_ARC * pow(reach, 9.0), Color(_STAR, minf(lit, 1.0)), 1)

	var falling: int = int(roundf(fall * _mote_reach.size()))
	for i: int in falling:
		var reach: float = _mote_reach[i]
		# A speck far off, a chunk up close.
		var size: int = 1 + int(reach * reach * 3.0)
		var angle: float = _mote_angle[i] + turn
		_draw_arc_pixels(reach * radius, angle, size + 10.0 * pow(reach, 6.0), _mote_color[i], size)


## How much of the rim's pull reaches [param reach] (0 middle, 1 rim).
func _rim_weight(reach: float) -> float:
	return pow(reach, 5.0)


## Radians per second a falling mote at [param reach] swings round.
func _swirl(reach: float) -> float:
	return drag * 6.0 * _rim_weight(reach)


## A smear [param length] art pixels long along the circle of [param r]
## round the origin, centred on [param angle], [param thickness] pixels
## thick. Placed a whole pixel at a time.
func _draw_arc_pixels(r: float, angle: float, length: float, color: Color, thickness: int) -> void:
	var steps: int = maxi(1, int(roundf(length)))
	var half: float = (steps - 1) / 2.0
	var drawn: Dictionary[Vector2i, bool] = {}
	for s: int in steps:
		var a: float = angle + (s - half) / maxf(r, 1.0)
		var at: Vector2 = Vector2(sin(a), -cos(a)) * r
		var pixel: Vector2i = Vector2i(floori(at.x), floori(at.y))
		if drawn.has(pixel):
			continue
		drawn[pixel] = true
		draw_rect(Rect2(Vector2(pixel) - Vector2.ONE * floorf(thickness / 2.0), Vector2.ONE * thickness), color)


func _randf(from: float, to: float) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, from, to)
