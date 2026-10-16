class_name CockpitGlassShards
extends Node2D
## Bits of canopy glass knocked loose by a crack. They tumble down inside the
## cockpit, land on whatever is under them (the dash, the top of the main
## viewer), bounce once, glint a while and fade.
##
## The floor is the cockpit itself: a shard lands on the first opaque pixel
## below it of the walls texture, or of any sprite in the
## [constant SURFACE_GROUP] group (the panels standing in front of the dash).
## No collision shapes to keep in step with the art: redraw the cockpit and
## the shards land on the new one. A panel that moves away from under a shard
## drops it again.
##
## CPUParticles2D can't collide, so the shards are simulated and drawn here.

const _SHEET: Texture2D = preload("res://Assets/Textures/UI/Cockpit/Damage/glass_shard-Sheet.png")
## Sprites in this group are solid to falling glass, wherever they are.
const SURFACE_GROUP: StringName = &"cockpit_surface"

const _TINKLE_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/glass_tinkle.tres")

const _FRAME_SIZE: int = 5
## Sheet frames: a sliver turning through four angles, and two chunks.
## A tumbling sliver steps through _SLIVER_SPIN; a chunk flips between its two.
const _SLIVER_SPIN: Array[int] = [0, 1, 2, 3]
const _CHUNKS: Array[int] = [4, 5]
## Slivers come to rest lying down: flat or at a slant, never on end.
const _SLIVER_RESTS: Array[int] = [1, 2, 3]

## Past this, a shard has fallen out of the cockpit and is gone.
const _OFF_SCREEN_Y: float = 200.0

enum State { FALLING, RESTING, FADING, BLOWN }


class Shard:
	var position: Vector2
	var velocity: Vector2
	var frame: int
	var flip_h: bool
	var flip_v: bool
	var sliver: bool
	var spin_index: int
	var spin_timer: float
	var spin_rate: float
	var state: int = State.FALLING
	var bounced: bool = false
	## Starting inside the shell (a crack at the canopy's edge), it falls
	## clear before anything can catch it.
	var armed: bool = false
	var timer: float = 0.0
	var rest_time: float = 0.0
	var alpha: float = 1.0
	var glint: float = 0.0
	var spill_id: int = 0


@export var gravity: float = 260.0
## Fraction of the landing speed a shard bounces back up with, once.
@export var bounce: float = 0.3
## Below this landing speed it just settles instead of bouncing.
@export var min_bounce_speed: float = 40.0
## Seconds a landed shard lies there (min, max) before it fades.
@export var rest_time: Vector2 = Vector2(2.5, 4.5)
@export var fade_time: float = 0.8

var _shards: Array[Shard] = []
## The cockpit shell; the grouped panels are looked up fresh on every spill,
## since they come and go with the player.
var _walls: Sprite2D = null
var _surfaces: Array[Sprite2D] = []
var _images: Dictionary[Texture2D, Image] = {}
## Whether shards land at all. Once the shell is blown apart there's nothing
## left to land on.
var _floors_enabled: bool = true
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_spill_id: int = 0
## Spills that have already tinkled: one landing sound each, not one a shard.
var _tinkled: Dictionary[int, bool] = {}


func _ready() -> void:
	_rng.randomize()
	set_process(false)


## Points the shards at the cockpit shell they land on.
func set_walls(walls: Sprite2D) -> void:
	_walls = walls


## Knocks [param count] shards loose at [param global_point]. They spill
## mostly downward, a little out to either side, as if pushed in through the
## glass.
func spill(global_point: Vector2, count: int, speed: float = 50.0) -> void:
	_gather_surfaces()
	var spill_id: int = _new_spill_id()
	for i: int in count:
		var direction: Vector2 = Vector2.DOWN.rotated(_rng.randf_range(-1.2, 1.2))
		_add_shard(global_point + Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-2, 2)),
				direction * _rng.randf_range(speed * 0.3, speed) + Vector2(0, -speed * 0.35),
				spill_id)


## Blows every shard (and [param extra] new ones from each of [param points])
## away from [param origin], for the shell coming apart. Nothing lands now.
func blow_away(origin: Vector2, points: Array[Vector2], extra: int) -> void:
	_floors_enabled = false
	var spill_id: int = _new_spill_id()
	for point: Vector2 in points:
		for i: int in extra:
			_add_shard(point, Vector2.ZERO, spill_id)
	for shard: Shard in _shards:
		var away: Vector2 = to_global(shard.position) - origin
		if away.length() < 1.0:
			away = Vector2.UP
		shard.velocity = away.normalized().rotated(_rng.randf_range(-0.5, 0.5)) \
				* _rng.randf_range(80.0, 200.0) + Vector2(0, -40)
		shard.state = State.BLOWN
		shard.timer = 0.0
		shard.rest_time = _rng.randf_range(1.0, 1.8)
		shard.spin_rate = _rng.randf_range(0.03, 0.06)


func clear() -> void:
	_shards.clear()
	_tinkled.clear()
	queue_redraw()


func get_shard_count() -> int:
	return _shards.size()


func _new_spill_id() -> int:
	_next_spill_id += 1
	return _next_spill_id


func _add_shard(global_point: Vector2, velocity: Vector2, spill_id: int) -> void:
	var shard: Shard = Shard.new()
	shard.position = to_local(global_point)
	shard.velocity = velocity
	shard.sliver = _rng.randf() < 0.65
	shard.spin_index = _rng.randi() % _SLIVER_SPIN.size()
	shard.frame = _SLIVER_SPIN[shard.spin_index] if shard.sliver \
			else _CHUNKS[_rng.randi() % _CHUNKS.size()]
	shard.flip_h = _rng.randf() < 0.5
	shard.flip_v = false
	shard.spin_rate = _rng.randf_range(0.05, 0.12)
	shard.spin_timer = _rng.randf() * shard.spin_rate
	shard.spill_id = spill_id
	_shards.append(shard)
	set_process(true)


func _process(delta: float) -> void:
	for i: int in range(_shards.size() - 1, -1, -1):
		var shard: Shard = _shards[i]
		match shard.state:
			State.FALLING:
				_fall(shard, delta)
			State.RESTING:
				_rest(shard, delta)
			State.FADING:
				shard.timer += delta
				shard.alpha = 1.0 - shard.timer / fade_time
			State.BLOWN:
				_blown(shard, delta)
		if shard.alpha <= 0.0 or shard.position.y > _OFF_SCREEN_Y:
			_shards.remove_at(i)
	if _shards.is_empty():
		_tinkled.clear()
		set_process(false)
	queue_redraw()


func _fall(shard: Shard, delta: float) -> void:
	_tumble(shard, delta)
	shard.velocity.y += gravity * delta
	shard.velocity.x *= 1.0 - 1.5 * delta
	var from: Vector2 = shard.position
	shard.position += shard.velocity * delta
	if not _floors_enabled or shard.velocity.y <= 0.0:
		return

	var surface: int = _surface_between(from, shard.position, shard)
	if surface < 0:
		return
	# The shard's art sits in the middle of its frame; rest it on the surface.
	shard.position.y = surface - 1.5
	_land(shard)


## Called whenever a falling shard reaches a surface: the first hard landing
## bounces it, anything after that lays it down.
func _land(shard: Shard) -> void:
	if not _tinkled.has(shard.spill_id):
		_tinkled[shard.spill_id] = true
		Events.play_sound.emit(_TINKLE_SFX)
	if not shard.bounced and shard.velocity.y > min_bounce_speed:
		shard.bounced = true
		shard.velocity = Vector2(shard.velocity.x * 0.5 + _rng.randf_range(-10, 10),
				-shard.velocity.y * bounce)
		shard.glint = 0.12
		return
	shard.state = State.RESTING
	shard.velocity = Vector2.ZERO
	shard.timer = 0.0
	shard.rest_time = _rng.randf_range(rest_time.x, rest_time.y)
	if shard.sliver:
		shard.frame = _SLIVER_RESTS[_rng.randi() % _SLIVER_RESTS.size()]
	shard.flip_v = false
	shard.glint = 0.15


func _rest(shard: Shard, delta: float) -> void:
	if not _floors_enabled or not _is_solid(to_global(shard.position) + Vector2(0, 2)):
		# Whatever it was lying on has gone.
		shard.state = State.FALLING
		shard.bounced = true
		shard.armed = true
		return
	shard.timer += delta
	shard.glint = maxf(0.0, shard.glint - delta)
	# Now and then catches the light where it lies.
	if shard.glint <= 0.0 and _rng.randf() < delta * 0.35:
		shard.glint = 0.1
	if shard.timer >= shard.rest_time:
		shard.state = State.FADING
		shard.timer = 0.0


func _blown(shard: Shard, delta: float) -> void:
	_tumble(shard, delta)
	shard.velocity.y += gravity * 0.4 * delta
	shard.position += shard.velocity * delta
	shard.timer += delta
	shard.alpha = 1.0 - smoothstep(shard.rest_time * 0.5, shard.rest_time, shard.timer)


func _tumble(shard: Shard, delta: float) -> void:
	shard.glint = maxf(0.0, shard.glint - delta)
	shard.spin_timer -= delta
	if shard.spin_timer > 0.0:
		return
	shard.spin_timer = shard.spin_rate
	if shard.sliver:
		shard.spin_index = (shard.spin_index + 1) % _SLIVER_SPIN.size()
		shard.frame = _SLIVER_SPIN[shard.spin_index]
	else:
		shard.flip_v = not shard.flip_v
		if shard.flip_v:
			shard.flip_h = not shard.flip_h


## The first solid pixel the shard passes through on its way from
## [param from] to [param to] (local), as a local y, or -1 if it's still in
## the clear.
func _surface_between(from: Vector2, to: Vector2, shard: Shard) -> int:
	var offset: Vector2 = to_global(Vector2.ZERO)
	var x: float = floorf(to.x + offset.x) + 0.5
	# The shard's bottom edge, not its middle, is what touches down.
	var start: int = floori(from.y + offset.y + 1.5)
	var end: int = floori(to.y + offset.y + 1.5)
	for y: int in range(start, end + 1):
		var solid: bool = _is_solid(Vector2(x, y + 0.5))
		if not shard.armed:
			shard.armed = not solid
			continue
		if solid:
			return floori(y - offset.y)
	return -1


func _gather_surfaces() -> void:
	_surfaces.clear()
	if is_instance_valid(_walls):
		_surfaces.append(_walls)
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(SURFACE_GROUP):
		if node is Sprite2D:
			_surfaces.append(node)


## Whether any visible surface has an opaque pixel at [param global_point].
func _is_solid(global_point: Vector2) -> bool:
	for sprite: Sprite2D in _surfaces:
		if not is_instance_valid(sprite) or not sprite.is_visible_in_tree() or not sprite.texture:
			continue
		var local: Vector2 = sprite.to_local(global_point)
		var rect: Rect2 = sprite.get_rect()
		if not rect.has_point(local):
			continue
		var image: Image = _image_of(sprite.texture)
		var pixel: Vector2i = Vector2i((local - rect.position).floor())
		if sprite.region_enabled:
			pixel += Vector2i(sprite.region_rect.position)
		if pixel.x < image.get_width() and pixel.y < image.get_height() \
				and image.get_pixel(pixel.x, pixel.y).a > 0.0:
			return true
	return false


func _image_of(texture: Texture2D) -> Image:
	if not _images.has(texture):
		_images[texture] = texture.get_image()
	return _images[texture]


func _draw() -> void:
	for shard: Shard in _shards:
		var size: Vector2 = Vector2(_FRAME_SIZE, _FRAME_SIZE)
		var top_left: Vector2 = (shard.position - size / 2.0).round()
		var rect: Rect2 = Rect2(top_left, size)
		if shard.flip_h:
			rect = Rect2(top_left + Vector2(size.x, 0), Vector2(-size.x, size.y))
		if shard.flip_v:
			rect = Rect2(rect.position + Vector2(0, size.y), Vector2(rect.size.x, -size.y))
		var source: Rect2 = Rect2(shard.frame * _FRAME_SIZE, 0, _FRAME_SIZE, _FRAME_SIZE)
		var tint: Color = Color(1, 1, 1, shard.alpha)
		draw_texture_rect_region(_SHEET, rect, source, tint)
		if shard.glint > 0.0:
			var centre: Vector2 = top_left + size / 2.0 - Vector2(0.5, 0.5)
			var white: Color = Color(Globals.white, shard.alpha)
			draw_rect(Rect2(centre, Vector2.ONE), white)
			draw_rect(Rect2(centre + Vector2(-1, 0), Vector2(3, 1)), Color(white, white.a * 0.6))
			draw_rect(Rect2(centre + Vector2(0, -1), Vector2(1, 3)), Color(white, white.a * 0.6))
