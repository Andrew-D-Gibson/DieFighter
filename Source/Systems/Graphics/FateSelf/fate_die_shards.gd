class_name FateDieShards
extends Node2D
## The canopy's bone die in pieces (RECKONING_ENDINGS.md §4): its own art cut
## into a dozen shards that burst from where it broke, hang a beat, then
## stream out through the canopy to "You" and close in on the point the cube
## forms at. Each trails a pixel of Fate's purple. Drawn whole-pixel in world
## space, so the pieces stay the art's own pixels.

## Every shard is in.
signal gathered

## Where the die is cut, in its own pixels: a grid of uneven pieces.
const _CUTS_X: Array[int] = [0, 3, 6, 8, 11]
const _CUTS_Y: Array[int] = [0, 4, 7, 11]
const _BURST_SECONDS: float = 0.38
const _BURST_SPEED: float = 45.0
const _BURST_DAMPING: float = 6.0
## Each shard's flight to the ship, and the stagger between them, so they read
## as a stream rather than a volley.
const _FLIGHT_SECONDS: float = 0.8
const _STAGGER_SECONDS: float = 0.045
## How far a flight bows off the straight line, as a share of its length.
const _BOW: float = 0.2
## Seconds of trail behind each shard in flight, drawn as a streak.
const _TRAIL_SECONDS: float = 0.1
## Over the canopy and the ships: the shards cross both.
const _Z: int = 30

var _texture: Texture2D
var _target: Callable
var _shards: Array[Dictionary] = []
var _time: float = 0.0
var _gathered: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = _Z


## Shatters [param texture] (the die as it looked) at [param from], then flies
## the pieces to wherever [param target] (returning a world point) says,
## following it as it moves.
func fly(from: Vector2, texture: Texture2D, target: Callable) -> void:
	_texture = texture
	_target = target
	_rng.seed = 0xd1e
	var half: Vector2 = Vector2(FateDieArt.SIZE, FateDieArt.SIZE) / 2.0
	var index: int = 0
	for row: int in _CUTS_Y.size() - 1:
		for column: int in _CUTS_X.size() - 1:
			var source: Rect2 = Rect2(_CUTS_X[column], _CUTS_Y[row],
				_CUTS_X[column + 1] - _CUTS_X[column], _CUTS_Y[row + 1] - _CUTS_Y[row])
			var offset: Vector2 = source.get_center() - half
			var outward: Vector2 = offset.normalized() if offset.length() > 0.5 else Vector2.UP
			_shards.append({
				"source": source,
				"position": from + offset,
				"velocity": (outward * _rng.randf_range(0.6, 1.0) + Vector2(_rng.randf_range(-0.3, 0.3), -0.2)) * _BURST_SPEED,
				"delay": 0.0,
				"start": Vector2.ZERO,
				"bow": _rng.randf_range(0.7, 1.2) * (1.0 if index % 3 != 0 else -0.5),
				"trail": PackedVector2Array(),
				"trail_times": PackedFloat32Array(),
				"done": false,
			})
			index += 1
	# Furthest from the ship first, so the stream unspools toward it.
	var aim: Vector2 = _target.call()
	_shards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["position"] as Vector2).distance_squared_to(aim) > (b["position"] as Vector2).distance_squared_to(aim))
	for i: int in _shards.size():
		_shards[i]["delay"] = i * _STAGGER_SECONDS


func _process(delta: float) -> void:
	if _texture == null or _gathered:
		return
	_time += delta
	var aim: Vector2 = _target.call()
	var all_in: bool = true
	for shard: Dictionary in _shards:
		var position_now: Vector2 = shard["position"]
		if _time < _BURST_SECONDS:
			var velocity: Vector2 = shard["velocity"]
			position_now += velocity * delta
			shard["velocity"] = velocity * exp(-_BURST_DAMPING * delta)
			shard["start"] = position_now
		else:
			var t: float = clampf((_time - _BURST_SECONDS - float(shard["delay"])) / _FLIGHT_SECONDS, 0.0, 1.0)
			if t < 1.0:
				all_in = false
			elif not shard["done"]:
				shard["done"] = true
				Juice.sparkle(get_parent(), aim, Globals.purple, 2, 18.0)
			var start: Vector2 = shard["start"]
			var line: Vector2 = aim - start
			var bend: Vector2 = (start + aim) * 0.5 + line.orthogonal() * _BOW * float(shard["bow"])
			# Slow to leave, fast to arrive: pulled in.
			var eased: float = t * t * t
			position_now = start.lerp(bend, eased).lerp(bend.lerp(aim, eased), eased)
		var trail: PackedVector2Array = shard["trail"]
		var times: PackedFloat32Array = shard["trail_times"]
		trail.append(position_now)
		times.append(_time)
		while times.size() > 2 and _time - times[0] > _TRAIL_SECONDS:
			trail.remove_at(0)
			times.remove_at(0)
		shard["trail"] = trail
		shard["trail_times"] = times
		shard["position"] = position_now
	if _time < _BURST_SECONDS:
		all_in = false
	queue_redraw()
	if all_in:
		_gathered = true
		gathered.emit()
		queue_free()


func _draw() -> void:
	if _texture == null:
		return
	for shard: Dictionary in _shards:
		if shard["done"]:
			continue
		var trail: PackedVector2Array = shard["trail"]
		if _time >= _BURST_SECONDS:
			for i: int in trail.size() - 1:
				var color: Color = Globals.purple if i == trail.size() - 2 else Globals.medium_purple
				_draw_streak(to_local(trail[i]), to_local(trail[i + 1]), color)
		var source: Rect2 = shard["source"]
		var at: Vector2 = to_local(shard["position"]).round() - source.size / 2.0
		draw_texture_rect_region(_texture, Rect2(at.round(), source.size), source)


## A line a pixel at a time, so a streak stays on the art grid at any angle.
func _draw_streak(from: Vector2, to: Vector2, color: Color) -> void:
	var steps: int = maxi(1, int(from.distance_to(to)))
	for i: int in steps:
		draw_rect(Rect2(from.lerp(to, i / float(steps)).round(), Vector2.ONE), color)
