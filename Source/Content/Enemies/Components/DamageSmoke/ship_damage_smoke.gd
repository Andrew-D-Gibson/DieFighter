class_name ShipDamageSmoke
extends Node2D
## Smoke that breaks out of a ship's hull as it takes damage: nothing at full
## hull, then one more plume at each of [constant THRESHOLDS]. A heal puts them
## out again in reverse order.
##
## Every ship of a kind smokes from the same spots, in the same order. That is
## what lets the opening cutscene's Survivor, an Attacker holed on screen, look
## the same as the Attacker the opening ambush spawns on that much hull.
##
## The spots come from the hull's own opaque pixels, picked by an RNG seeded
## from its texture, so a new enemy smokes without any authoring. They keep
## off the ship's face (see [constant _FACE_HALF_WIDTH]): the player reads an
## enemy by its cockpit, eye or core, and a plume over it hides who's firing.
## To place them by hand, give the ship graphics scene a Node2D named
## DamageSmokePoints holding one Marker2D per plume, in the order they should
## break out.
##
## The plumes emit in world space, so a moving or bobbing ship leaves its smoke
## behind it as a trail, the way the cutscene's ships do.

## The hull fractions at or below which each plume breaks out, in order.
const THRESHOLDS: PackedFloat32Array = [0.75, 0.5, 0.25]

## The node in a ship graphics scene whose Marker2D children pin the spots.
const POINTS_NODE: NodePath = ^"DamageSmokePoints"

const _PIXEL_TEXTURE: Texture2D = preload("res://Assets/Particles/hit_particle_pixel.png")

## The way smoke drifts off the hull, in the ship's own space. Enemy sheets
## are drawn nose-down, so their tails are up.
const _TAIL: Vector2 = Vector2.UP

## A pixel only counts as hull this opaque, so a spot never lands on the
## soft edge of a glow.
const _OPAQUE_ALPHA: float = 0.5

## The smoke's greys, from fresh to the haze it fades out as.
const _SMOKE_LIGHT: Color = Color("#a5a29d")
const _SMOKE_DARK: Color = Color("#63605c")

## How solid a hull plume's smoke is. Thin enough that the art under it still
## reads; the fire at its source stays solid, so the damage does too.
const _PLUME_HAZE: float = 0.6

## Where an enemy's face is: the middle of the hull, from a little behind its
## centre to the nose. Sheets are nose-down, so this is the cockpit, eye or
## core almost every ship is drawn around. As fractions of the hull's opaque
## bounds: the column's half width, and how far behind the centre it starts.
const _FACE_HALF_WIDTH: float = 0.22
const _FACE_REAR_REACH: float = 0.15

## Spots per hull texture: every ship of a kind shares them, and reading
## the image back is the only costly part.
static var _spot_cache: Dictionary[String, PackedVector2Array] = {}

var _plumes: Array[CPUParticles2D] = []
var _health: Health


## Builds the plumes for [param hull], all out, and mounts them on it.
static func attach(hull: Sprite2D) -> ShipDamageSmoke:
	var smoke: ShipDamageSmoke = ShipDamageSmoke.new()
	smoke.name = &"DamageSmoke"
	for spot: Vector2 in spots_for(hull):
		var plume: CPUParticles2D = plume_particles()
		plume.position = spot
		plume.emitting = false
		smoke.add_child(plume)
		smoke._plumes.append(plume)
	hull.add_child(smoke)
	return smoke


## How many plumes a ship [param fraction] of the way to full hull shows.
static func plume_count(fraction: float) -> int:
	var count: int = 0
	for threshold: float in THRESHOLDS:
		if fraction <= threshold:
			count += 1
	return count


## Lights the plumes [param fraction] of a full hull calls for and puts the
## rest out. Smoke already in the air drifts off rather than vanishing.
func set_hull_fraction(fraction: float) -> void:
	var lit: int = plume_count(fraction)
	for i: int in _plumes.size():
		_plumes[i].emitting = i < lit


## Puts the smoke out for good, including what's already in the air: the
## ship is dying, and its kill should read as one clean silhouette. Stops
## listening to the hull too, so nothing relights it on the way out.
func extinguish() -> void:
	if _health and _health.health_set.is_connected(_on_health_set):
		_health.health_set.disconnect(_on_health_set)
	_health = null
	visible = false
	for plume: CPUParticles2D in _plumes:
		plume.emitting = false
	queue_free()


## Keeps the plumes in step with [param health] from here on.
func track(health: Health) -> void:
	if _health:
		_health.health_set.disconnect(_on_health_set)
	_health = health
	_health.health_set.connect(_on_health_set)
	_on_health_set()


func _on_health_set() -> void:
	# A ship whose hull hasn't been set up yet has nothing to show.
	if _health.max_health <= 0:
		set_hull_fraction(1.0)
		return
	set_hull_fraction(float(_health.health) / float(_health.max_health))


## One plume of smoke. The look is the opening cutscene's damage smoke, slowed
## for a ship that mostly hangs in place.
static func plume_particles() -> CPUParticles2D:
	var plume: CPUParticles2D = CPUParticles2D.new()
	plume.texture = _PIXEL_TEXTURE
	plume.amount = 24
	plume.lifetime = 1.0
	plume.local_coords = false
	plume.direction = _TAIL
	plume.spread = 25.0
	plume.gravity = Vector2(0, -6)
	plume.initial_velocity_min = 8.0
	plume.initial_velocity_max = 18.0
	plume.scale_amount_min = 1.0
	plume.scale_amount_max = 3.0
	plume.color_ramp = smoke_ramp(_PLUME_HAZE)
	return plume


## Fire at the source, cooling through grey to nothing. [param haze] is how
## solid the grey is; the fire stays solid.
static func smoke_ramp(haze: float = 1.0) -> Gradient:
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.5, 1.0])
	ramp.colors = PackedColorArray([Globals.orange, Color(_SMOKE_LIGHT, haze),
		Color(_SMOKE_DARK, haze), Color(_SMOKE_DARK, 0.0)])
	return ramp


## Where [param hull]'s plumes break out, in order, in its own space: the
## markers under [constant POINTS_NODE] if it has them, picked from its pixels
## if not.
static func spots_for(hull: Sprite2D) -> PackedVector2Array:
	var authored: Node = hull.get_node_or_null(POINTS_NODE)
	if authored is Node2D:
		var pinned: PackedVector2Array = PackedVector2Array()
		for marker: Node in authored.get_children():
			if marker is Marker2D:
				pinned.append((authored as Node2D).transform * (marker as Marker2D).position)
		return pinned
	if hull.texture == null:
		return PackedVector2Array()
	var key: String = hull.texture.resource_path
	if not _spot_cache.has(key):
		_spot_cache[key] = _pick_spots(hull)
	return _spot_cache[key]


## Picks [constant THRESHOLDS]'s worth of spots well inside the hull, spread
## apart. Seeded from the texture rather than the game's RNG, so the same hull
## picks the same spots in every run, scene and save.
static func _pick_spots(hull: Sprite2D) -> PackedVector2Array:
	var image: Image = hull.texture.get_image()
	if image == null:
		return PackedVector2Array()
	if image.is_compressed():
		image.decompress()
	var frame: Rect2i = _frame_rect(hull)

	# Pixels with hull on all four sides, so the smoke rises out of the ship
	# rather than off its outline.
	var interior: Array[Vector2i] = []
	for y: int in range(frame.position.y + 1, frame.end.y - 1):
		for x: int in range(frame.position.x + 1, frame.end.x - 1):
			if _is_hull(image, x, y) and _is_hull(image, x - 1, y) and _is_hull(image, x + 1, y) \
					and _is_hull(image, x, y - 1) and _is_hull(image, x, y + 1):
				interior.append(Vector2i(x, y))
	if interior.is_empty():
		return PackedVector2Array([Vector2.ZERO])
	var bounds: Rect2i = Rect2i(interior[0], Vector2i.ONE)
	for pixel: Vector2i in interior:
		bounds = bounds.merge(Rect2i(pixel, Vector2i.ONE))

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(hull.texture.resource_path)
	# Fisher-Yates with the seeded RNG; Array.shuffle() would use the global one.
	for i: int in range(interior.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Vector2i = interior[i]
		interior[i] = interior[j]
		interior[j] = swap

	# Off the face where the hull allows it; a hull that's nearly all face
	# smokes from it rather than not at all.
	var off_face: Array[Vector2i] = []
	for pixel: Vector2i in interior:
		if not _is_face(pixel, bounds):
			off_face.append(pixel)
	var picked: Array[Vector2i] = _spread_out(off_face, [], frame)
	if picked.size() < THRESHOLDS.size():
		picked = _spread_out(interior, picked, frame)

	var origin: Vector2 = Vector2(frame.position) + (Vector2(frame.size) / 2.0 if hull.centered else Vector2.ZERO)
	var spots: PackedVector2Array = PackedVector2Array()
	for pixel: Vector2i in picked:
		# The middle of the pixel, relative to where the sprite draws from.
		spots.append(Vector2(pixel) + Vector2(0.5, 0.5) - origin + hull.offset)
	return spots


## Up to [constant THRESHOLDS]'s worth of [param pixels], on top of
## [param picked], as far apart as a third of the hull's short side allows,
## so plumes read as separate damage; closer if the hull is too small for that.
static func _spread_out(pixels: Array[Vector2i], picked: Array[Vector2i], frame: Rect2i) -> Array[Vector2i]:
	var spots: Array[Vector2i] = picked.duplicate()
	var spacing: float = maxf(3.0, mini(frame.size.x, frame.size.y) / 3.0)
	while spots.size() < THRESHOLDS.size() and spacing >= 1.0:
		for pixel: Vector2i in pixels:
			if spots.size() >= THRESHOLDS.size():
				break
			if spots.all(func(other: Vector2i) -> bool: return Vector2(pixel).distance_to(Vector2(other)) >= spacing):
				spots.append(pixel)
		spacing /= 2.0
	return spots


## Whether [param pixel] is on the face of a hull whose interior spans
## [param bounds]. See [constant _FACE_HALF_WIDTH].
static func _is_face(pixel: Vector2i, bounds: Rect2i) -> bool:
	var centre: Vector2 = Vector2(bounds.position) + Vector2(bounds.size) / 2.0
	var middle: Vector2 = Vector2(pixel) + Vector2(0.5, 0.5)
	return absf(middle.x - centre.x) < bounds.size.x * _FACE_HALF_WIDTH \
		and middle.y > centre.y - bounds.size.y * _FACE_REAR_REACH


static func _is_hull(image: Image, x: int, y: int) -> bool:
	return image.get_pixel(x, y).a >= _OPAQUE_ALPHA


## The part of the texture [param hull] draws: its region and current frame.
static func _frame_rect(hull: Sprite2D) -> Rect2i:
	var sheet: Rect2i = Rect2i(hull.region_rect) if hull.region_enabled \
		else Rect2i(Vector2i.ZERO, hull.texture.get_size())
	var grid: Vector2i = Vector2i(hull.hframes, hull.vframes)
	var size: Vector2i = sheet.size / grid
	var cell: Vector2i = Vector2i(hull.frame % grid.x, hull.frame / grid.x)
	return Rect2i(sheet.position + cell * size, size)
