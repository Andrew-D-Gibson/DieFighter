class_name ShipWreck
extends Node2D
## A killed ship coming apart: the hull cracks into a few pieces that drift
## off on their own and blow up one after another, rather than the whole wreck
## sailing away to go up in a single bang.
##
## Each piece is every sprite of the ship cut down to one wedge of the hull,
## so any ship scene breaks up, however many sprites it's built from.
## The wedges share their crack lines, so the pieces fit back together exactly
## at the moment the hull gives way.
##
## Frees itself once the last explosion has played out.

signal finished

## Small hulls split three ways, big ones four.
const _PIECES_SMALL: int = 3
const _PIECES_LARGE: int = 4
const _LARGE_HULL_SIZE: float = 48.0

## How far each piece drifts, how long it takes, and how much it turns.
const _DRIFT_DISTANCE_MIN: float = 8.0
const _DRIFT_DISTANCE_MAX: float = 18.0
const _DRIFT_SECONDS: float = 1.1
const _DRIFT_SPIN_MAX: float = TAU * 0.3
## How much of each piece's heading comes from the killing blow rather than
## its own place in the hull. The blow carries the wreck the way it was hit;
## the rest keeps the pieces from moving as one.
const _KICK_WEIGHT: float = 0.6

## When the pieces blow, in seconds after the hull cracks: the first once the
## crack has had a moment to register, the rest strung out behind it, never
## quite evenly.
const _FIRST_BLAST_SECONDS: float = 0.22
const _BLAST_SPACING_SECONDS: float = 0.22
const _BLAST_JITTER_SECONDS: float = 0.06
## How big each piece's explosion draws next to the explosion art, and how fast
## it plays. Smaller and quicker than the one big blast a whole ship used to
## get, since there are several.
const _BLAST_SCALE_MIN: float = 0.75
const _BLAST_SCALE_MAX: float = 1.05
const _BLAST_SPEED: float = 1.3

## How far the crack lines wander off straight, in pixels.
const _CRACK_JAG: float = 3.0
## The wedges reach well past the hull, so no corner of the art is left out.
const _WEDGE_REACH: float = 1.5

const _SPARK_TEXTURE: Texture2D = preload("res://Assets/Particles/hit_particle_pixel.png")

var _explosion_scene: PackedScene
var _blast_sound: SoundEffectResource
var _blasts_left: int = 0


## Breaks [param ship_graphics] up into pieces drawn under [param parent],
## where the ship was. [param kick] is the direction the killing blow came
## from, or zero to let the pieces scatter evenly. On the game's pixel grid,
## like the effects around it.
static func shatter(
	parent: Node,
	ship_graphics: Node2D,
	kick: Vector2,
	explosion_scene: PackedScene,
	blast_sound: SoundEffectResource
) -> ShipWreck:
	var wreck: ShipWreck = ShipWreck.new()
	wreck._explosion_scene = explosion_scene
	wreck._blast_sound = blast_sound
	var view: JuicePixelated = JuicePixelated.spawn(parent, wreck, 0)
	view.global_transform = ship_graphics.global_transform
	wreck._break(ship_graphics, kick)
	return wreck


func _break(ship_graphics: Node2D, kick: Vector2) -> void:
	var hull: Rect2 = _hull_rect(ship_graphics)
	var count: int = _PIECES_LARGE if hull.size.x >= _LARGE_HULL_SIZE else _PIECES_SMALL
	var reach: float = hull.size.length() * _WEDGE_REACH
	var cracks: Array[PackedVector2Array] = []
	var angles: Array[float] = []
	var start: float = _rand(0.0, TAU)
	for i: int in range(count):
		var spacing: float = TAU / count
		var angle: float = start + spacing * i + _rand(-0.2, 0.2) * spacing
		angles.append(angle)
		cracks.append(_crack(hull.get_center(), angle, reach))

	var blast_order: Array[int] = []
	for i: int in range(count):
		blast_order.append(i)
	RNGManager.shuffle_array(RNGManager.Bucket.COSMETIC, blast_order)

	_blasts_left = count
	for i: int in range(count):
		var next: int = (i + 1) % count
		var arc_to: float = angles[next] if next > i else angles[next] + TAU
		var wedge: PackedVector2Array = _wedge(hull.get_center(), cracks[i], cracks[next], angles[i], arc_to, reach)
		var heading: float = (angles[i] + arc_to) * 0.5
		# Where the piece's own share of the hull sits, roughly: the explosion
		# goes there, and the piece turns about it.
		var middle: Vector2 = hull.get_center() \
			+ Vector2.from_angle(heading) * hull.size * 0.25
		var piece: Node2D = _make_piece(ship_graphics, wedge, middle)
		var delay: float = _FIRST_BLAST_SECONDS + blast_order.find(i) * _BLAST_SPACING_SECONDS \
			+ _rand(-_BLAST_JITTER_SECONDS, _BLAST_JITTER_SECONDS)
		_drift(piece, Vector2.from_angle(heading), kick, maxf(delay, 0.0))


## The ship's art bounds in its own space. A ship scene's root is a Sprite2D;
## anything else gets a hull-sized guess.
static func _hull_rect(ship_graphics: Node2D) -> Rect2:
	if ship_graphics is Sprite2D:
		return (ship_graphics as Sprite2D).get_rect()
	return Rect2(-16, -16, 32, 32)


## A crack running out from [param from] along [param angle], kinked a little
## at a couple of points along the way.
func _crack(from: Vector2, angle: float, reach: float) -> PackedVector2Array:
	var direction: Vector2 = Vector2.from_angle(angle)
	var side: Vector2 = direction.orthogonal()
	var points: PackedVector2Array = PackedVector2Array()
	for along: float in [0.15, 0.3, 1.0]:
		var jag: float = 0.0 if along >= 1.0 else _rand(-_CRACK_JAG, _CRACK_JAG)
		points.append(from + direction * reach * along + side * jag)
	return points


## The wedge between two cracks: out along the first, round the far edge, and
## back in along the second, so neighbouring wedges share an edge exactly.
static func _wedge(
	centre: Vector2,
	crack_a: PackedVector2Array,
	crack_b: PackedVector2Array,
	from_angle: float,
	to_angle: float,
	reach: float
) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array([centre])
	points.append_array(crack_a)
	var steps: int = 4
	for step: int in range(1, steps):
		points.append(centre + Vector2.from_angle(lerpf(from_angle, to_angle, float(step) / steps)) * reach)
	var back: PackedVector2Array = crack_b.duplicate()
	back.reverse()
	points.append_array(back)
	return points


## One piece: every sprite of the ship cut down to [param wedge], turning
## about [param middle], with sparks streaming off it while it drifts.
func _make_piece(ship_graphics: Node2D, wedge: PackedVector2Array, middle: Vector2) -> Node2D:
	var piece: Node2D = Node2D.new()
	piece.position = middle
	add_child(piece)
	var body: Node2D = Node2D.new()
	body.position = -middle
	piece.add_child(body)
	for sprite: Sprite2D in _sprites_of(ship_graphics):
		_cut_sprite(sprite, ship_graphics, wedge, body)
	piece.add_child(_spark_trail())
	return piece


## The visible sprites the ship is drawn with, its root among them.
static func _sprites_of(root: Node) -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []
	if root is Sprite2D and (root as Sprite2D).texture and (root as Sprite2D).visible:
		sprites.append(root)
	for child: Node in root.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		sprites.append_array(_sprites_of(child))
	return sprites


## Adds the part of [param sprite] inside [param wedge] (in the ship's space)
## to [param body], as textured polygons drawn the way the sprite was. Cut
## rather than clipped: clipping inside the pixel view's transparent viewport
## fills the masked area in solid black.
static func _cut_sprite(sprite: Sprite2D, ship_graphics: Node2D, wedge: PackedVector2Array, body: Node2D) -> void:
	var to_ship: Transform2D = Transform2D.IDENTITY
	var node: Node = sprite
	while node != ship_graphics and node is Node2D:
		to_ship = (node as Node2D).transform * to_ship
		node = node.get_parent()
	var rect: Rect2 = sprite.get_rect()
	var corners: PackedVector2Array = PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y),
	])
	var source: Rect2 = _source_rect(sprite)
	for part: PackedVector2Array in Geometry2D.intersect_polygons(to_ship.affine_inverse() * wedge, corners):
		var shard: Polygon2D = Polygon2D.new()
		shard.transform = to_ship
		shard.texture = sprite.texture
		shard.polygon = part
		var uv: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in part:
			var offset: Vector2 = point - rect.position
			if sprite.flip_h:
				offset.x = rect.size.x - offset.x
			if sprite.flip_v:
				offset.y = rect.size.y - offset.y
			uv.append(source.position + offset)
		shard.uv = uv
		shard.material = sprite.material
		shard.modulate = sprite.modulate
		shard.self_modulate = sprite.self_modulate
		body.add_child(shard)


## Where in its texture [param sprite] draws from: its region, or its current
## frame of a sheet.
static func _source_rect(sprite: Sprite2D) -> Rect2:
	if sprite.region_enabled:
		return sprite.region_rect
	var size: Vector2 = sprite.texture.get_size() / Vector2(sprite.hframes, sprite.vframes)
	return Rect2(Vector2(sprite.frame_coords) * size, size)


func _spark_trail() -> CPUParticles2D:
	var sparks: CPUParticles2D = CPUParticles2D.new()
	sparks.texture = _SPARK_TEXTURE
	# World space, so the sparks hang where they were shed.
	sparks.local_coords = false
	sparks.amount = 12
	sparks.lifetime = 0.4
	sparks.spread = 180.0
	sparks.initial_velocity_min = 3.0
	sparks.initial_velocity_max = 10.0
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.0
	sparks.color = Globals.orange
	sparks.color_ramp = _fade_ramp()
	sparks.emitting = true
	return sparks


static func _fade_ramp() -> Gradient:
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(1, 1, 1, 0))
	return ramp


## Sends [param piece] off along a mix of [param outward] and [param kick],
## then blows it up after [param delay] seconds, wherever it has got to.
func _drift(piece: Node2D, outward: Vector2, kick: Vector2, delay: float) -> void:
	var heading: Vector2 = (outward * (1.0 - _KICK_WEIGHT) + kick * _KICK_WEIGHT).normalized() \
		if kick != Vector2.ZERO else outward
	var distance: float = _rand(_DRIFT_DISTANCE_MIN, _DRIFT_DISTANCE_MAX)
	var spin: float = _rand(-_DRIFT_SPIN_MAX, _DRIFT_SPIN_MAX)

	var tween: Tween = create_tween().set_parallel(true)
	# Expo out: the pieces burst apart and then hang, so each one is easy to
	# follow to its own explosion.
	tween.tween_property(piece, "position", piece.position + heading * distance, _DRIFT_SECONDS) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(piece, "rotation", spin, _DRIFT_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(delay).timeout.connect(_blow.bind(piece))


func _blow(piece: Node2D) -> void:
	if not is_instance_valid(piece):
		return
	# The piece goes at once; its sparks keep falling where they were shed.
	for child: Node in piece.get_children():
		if child is CPUParticles2D:
			(child as CPUParticles2D).emitting = false
		elif child is CanvasItem:
			(child as CanvasItem).visible = false

	var explosion: AnimatedSprite2D = _explosion_scene.instantiate()
	explosion.position = piece.position
	explosion.rotation = _rand(0.0, TAU)
	explosion.scale = Vector2.ONE * _rand(_BLAST_SCALE_MIN, _BLAST_SCALE_MAX)
	explosion.speed_scale = _BLAST_SPEED
	# The explosion scene frees itself; counting it out is how the wreck knows
	# when it's done.
	explosion.tree_exited.connect(_on_blast_gone, CONNECT_ONE_SHOT)
	add_child(explosion)
	Juice.sparkle(self, piece.global_position, Globals.red, 6, 30.0)
	Events.play_sound.emit(_blast_sound)
	Events.camera_shake_small.emit()


func _on_blast_gone() -> void:
	# The wreck being freed takes its explosions with it; that isn't them
	# finishing.
	if is_queued_for_deletion() or not is_inside_tree():
		return
	_blasts_left -= 1
	if _blasts_left == 0:
		finished.emit()
		queue_free()


func _rand(from: float, to: float) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, from, to)
