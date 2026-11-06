class_name ConsumedHull
extends Sprite2D
## The player's own hull in the consumed cutscene (ConsumedCutscene): their
## ship's cutscene_frames, with everything Fate does to it on top, keyed from
## the cutscene's timeline:
##   - [member gold], the Vanguard Drive's gold in its lights and flames;
##   - its flames, each going out on its own ([method snuff]);
##   - [member wash], Fate's cloak reaching across it from the hole's side;
##   - [member crack], cracks opening along the hull, lit purple from inside;
##   - [member stretch] toward the hole, and [member width] as it recedes.
##
## Ships draw their flames into their art, and every hull draws them
## differently, so the flames are found in the art itself: the patches of hot
## colour round the hull's exhaust points (ShipResource.cutscene_exhaust_points).
## The shader is consumed_hull.gdshader.

## A flame has just gone dark: [param at] is its nozzle, in local pixels.
signal flame_out(index: int, at: Vector2)

const _SHADER: Shader = preload("res://Source/Scenes/Cutscenes/Reckoning/Consumed/consumed_hull.gdshader")
const _PIXEL_TEXTURE: Texture2D = preload("res://Assets/Particles/hit_particle_pixel.png")
## The shader has room for this many flames.
const MAX_FLAMES: int = 8
## What FateLedger._dress_as_fallen washes the Fallen with.
const FALLEN_TINT: Color = Color("#c552f1")
const FALLEN_CLOAK: float = 0.4
## The Die Fighter's, for a ship that doesn't give its own.
const _DEFAULT_EXHAUST: PackedVector2Array = [Vector2(-8.5, 9.0), Vector2(8.5, 9.0)]
## How far from an exhaust point (in art pixels) a patch of hot colour can
## sit and still be that engine's flame rather than a running light.
const _FLAME_REACH: Vector2 = Vector2(7.0, 6.0)

## Keyed. How much of the drive burns gold: 1 all of it, 0 the art's colours.
@export var gold: float = 1.0:
	set(value):
		gold = value
		_set_param(&"gold", value)
## Keyed. How far across the hull Fate's cloak has reached, 0-1.
@export var wash: float = 0.0:
	set(value):
		wash = value
		_set_param(&"wash_reach", value)
## Keyed. How strongly the cloak tints the hull where it has reached. The
## Fallen wears [constant FALLEN_CLOAK].
@export var wash_strength: float = FALLEN_CLOAK:
	set(value):
		wash_strength = value
		_set_param(&"cloak_amount", value)
## The way to the hole, in the hull's own space (down is its tail).
@export var wash_from: Vector2 = Vector2.DOWN:
	set(value):
		wash_from = value
		_set_param(&"wash_from", value)
## Keyed. How far the cracks have opened, 0-1.
@export var crack: float = 0.0:
	set(value):
		crack = value
		_set_param(&"crack", value)
## Keyed. How far the cloak has sealed the cracks over again, 0-1.
@export var crack_seal: float = 0.0:
	set(value):
		crack_seal = value
		_set_param(&"crack_seal", value)
## Keyed. Drawn out along the hull's length (toward the hole), thinned to
## match. 1 is the hull as built.
@export var stretch: float = 1.0:
	set(value):
		stretch = value
		scale = Vector2(1.0 / sqrt(maxf(value, 0.01)), value)
## Keyed. How many art pixels wide the hull is drawn, shrunk the way
## PixelArtShrinker shrinks art. 0 is full size. Shrunk, it shows its first
## frame with the flames out.
@export var width: int = 0:
	set(value):
		if value == width:
			return
		width = value
		_show_frame()
## Keyed. Whether the drive's art animates; off holds the first frame, as
## the Fallen does.
@export var animating: bool = true
## Whether the gold exhaust plumes burn behind the flames. The Fallen's
## flames throw none.
@export var plumes: bool = true:
	set(value):
		plumes = value
		for i: int in _exhausts.size():
			_light_plume(i)

var _material: ShaderMaterial
var _frames: Array[Texture2D] = []
var _flame_masks: Array[Texture2D] = []
var _no_mask: ImageTexture
var _crack_mask: ImageTexture
var _frame_size: Vector2i = Vector2i(26, 28)
var _fps: float = 10.0
var _frame: int = 0
var _frame_clock: float = 0.0
## Per flame: "nozzle" (local pixels, where it leaves the hull), "exhaust"
## (which exhaust plume it feeds, or -1).
var _flames: Array[Dictionary] = []
var _power: PackedFloat32Array = PackedFloat32Array()
var _exhausts: Array[CPUParticles2D] = []
var _shrunk: Dictionary[int, ImageTexture] = {}
var _dark_frame: Image
var _snuffing: Dictionary[int, Tween] = {}


func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = _SHADER
	material = _material
	_no_mask = ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_RGBA8))
	_material.set_shader_parameter(&"flame_mask", _no_mask)
	_material.set_shader_parameter(&"crack_mask", _no_mask)
	_material.set_shader_parameter(&"cloak_main_color", FALLEN_TINT)
	_material.set_shader_parameter(&"cloak_bg_color", Color(FALLEN_TINT.darkened(0.45), 1.0))
	_power.resize(MAX_FLAMES)
	_power.fill(1.0)
	_push_power()


func _process(delta: float) -> void:
	if not animating or _frames.size() < 2 or width > 0:
		return
	_frame_clock += delta * _fps
	if _frame_clock >= 1.0:
		_frame_clock = fmod(_frame_clock, 1.0)
		_frame = (_frame + 1) % _frames.size()
		_show_frame()


## Takes on [param ship]'s cutscene hull ("boost", nose up), finds its flames
## and lights a gold exhaust plume at each of its exhaust points.
func dress(ship: ShipResource) -> void:
	var frames: SpriteFrames = ship.cutscene_frames if ship else null
	if frames == null or not frames.has_animation(&"boost") or frames.get_frame_count(&"boost") == 0:
		frames = load("res://Assets/Textures/Player/Ship/player_ship_frames.tres") as SpriteFrames
	var exhaust_points: PackedVector2Array = ship.cutscene_exhaust_points if ship else _DEFAULT_EXHAUST
	_fps = frames.get_animation_speed(&"boost")
	var images: Array[Image] = []
	for i: int in frames.get_frame_count(&"boost"):
		var image: Image = _image_of(frames.get_frame_texture(&"boost", i))
		if image:
			images.append(image)
	if images.is_empty():
		return
	_frame_size = images[0].get_size()
	_find_flames(images, exhaust_points)
	for image: Image in images:
		_frames.append(ImageTexture.create_from_image(image))
		_flame_masks.append(ImageTexture.create_from_image(_flame_mask(image)))
	_dark_frame = _without_flames(images[0])
	_crack_mask = ImageTexture.create_from_image(_cracks(images[0]))
	_material.set_shader_parameter(&"crack_mask", _crack_mask)
	for point: Vector2 in exhaust_points:
		_add_exhaust(point)
	_frame = 0
	_show_frame()


## The hull's width as built, in art pixels.
func frame_width() -> int:
	return _frame_size.x


## How many flames the hull has.
func flame_count() -> int:
	return _flames.size()


## Where flame [param index] leaves the hull, in local pixels.
func flame_nozzle(index: int) -> Vector2:
	return _flames[index]["nozzle"]


## The order the flames go out in: outermost first, alternating sides, so
## the drive dies from the outside in rather than all down one side.
func snuff_order() -> Array[int]:
	var order: Array[int] = []
	for i: int in _flames.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var ax: float = absf(flame_nozzle(a).x)
		var bx: float = absf(flame_nozzle(b).x)
		if not is_equal_approx(ax, bx):
			return ax > bx
		return flame_nozzle(a).x < flame_nozzle(b).x)
	return order


## Flame [param index] goes out over [param seconds]: it shortens toward its
## nozzle, catches and flickers, and goes dark. [signal flame_out] marks the
## moment it does.
func snuff(index: int, seconds: float = 0.9) -> void:
	if index < 0 or index >= _flames.size():
		return
	if _snuffing.has(index):
		_snuffing[index].kill()
	var out: Tween = create_tween()
	_snuffing[index] = out
	var shrink_time: float = seconds * 0.55
	out.tween_method(_set_power.bind(index), _power[index], 0.45, shrink_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# The flicker: a few catches, each fainter, with dark between.
	var catches: PackedFloat32Array = [0.15, 0.4, 0.05, 0.3, 0.0, 0.18]
	var beat: float = (seconds - shrink_time) / catches.size()
	for level: float in catches:
		out.tween_callback(_set_power.bind(level, index))
		out.tween_interval(beat)
	out.tween_callback(func() -> void:
		_set_power(0.0, index)
		flame_out.emit(index, flame_nozzle(index)))


## Every flame to [param power] at once (0 all out, 1 all burning).
func set_all_flames(power: float) -> void:
	for tween: Tween in _snuffing.values():
		tween.kill()
	_snuffing.clear()
	for i: int in _flames.size():
		_set_power(power, i)


## Whether the exhaust plumes are thrown hard, as a drive straining.
func strain(straining: bool) -> void:
	for exhaust: CPUParticles2D in _exhausts:
		exhaust.initial_velocity_min = 90.0 if straining else 50.0
		exhaust.initial_velocity_max = 130.0 if straining else 75.0


## A flash of [param color] over the hull, fading over [param seconds].
func flash(color: Color, peak: float, seconds: float) -> void:
	_material.set_shader_parameter(&"flash_color", color)
	var fade: Tween = create_tween()
	fade.tween_method(func(amount: float) -> void: _set_param(&"flash_amount", amount),
		Juice.soften_flash(peak), 0.0, seconds).set_ease(Tween.EASE_OUT)


## Holds the first frame, as the Fallen does.
func hold_first_frame() -> void:
	animating = false
	_frame = 0
	_show_frame()


# --- Drawing -----------------------------------------------------------------

func _show_frame() -> void:
	if _frames.is_empty():
		return
	if width > 0 and width < _frame_size.x:
		texture = _shrunk_texture(width)
		_set_param(&"flame_mask", _no_mask)
		_set_param(&"crack_mask", _no_mask)
		return
	texture = _frames[_frame]
	_set_param(&"flame_mask", _flame_masks[_frame])
	_set_param(&"crack_mask", _crack_mask if _crack_mask else _no_mask)


func _shrunk_texture(pixels: int) -> ImageTexture:
	if not _shrunk.has(pixels):
		_shrunk[pixels] = ImageTexture.create_from_image(PixelArtShrinker.shrink(_dark_frame, pixels))
	return _shrunk[pixels]


func _set_power(power: float, index: int) -> void:
	_power[index] = power
	_push_power()
	_light_plume(int(_flames[index]["exhaust"]))


## A plume burns while any flame feeding it does.
func _light_plume(plume: int) -> void:
	if plume < 0 or plume >= _exhausts.size():
		return
	var strongest: float = 0.0
	for i: int in _flames.size():
		if int(_flames[i]["exhaust"]) == plume:
			strongest = maxf(strongest, _power[i])
	_exhausts[plume].emitting = plumes and strongest > 0.35


func _push_power() -> void:
	_set_param(&"flame_power", _power)


func _set_param(param: StringName, value: Variant) -> void:
	if _material:
		_material.set_shader_parameter(param, value)


# --- Reading the art ---------------------------------------------------------

## Ships may give an AtlasTexture (a frame of a sheet) or a whole texture.
static func _image_of(frame: Texture2D) -> Image:
	if frame == null:
		return null
	var image: Image
	var atlas: AtlasTexture = frame as AtlasTexture
	if atlas and atlas.atlas:
		image = atlas.atlas.get_image().get_region(Rect2i(atlas.region))
	else:
		image = frame.get_image()
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	return image


## Hot colour, as a drive burns: saturated and bright, or near-white.
static func _is_hot(c: Color) -> bool:
	if c.a < 0.5:
		return false
	return (c.s > 0.3 and c.v > 0.35) or c.v > 0.85


## The flames: hot patches of art round each exhaust point, joined up across
## every frame so a flame that flickers longer in one frame is still one flame.
func _find_flames(images: Array[Image], exhaust_points: PackedVector2Array) -> void:
	_flames.clear()
	var half: Vector2 = Vector2(_frame_size) / 2.0
	var hot: Dictionary[Vector2i, bool] = {}
	for image: Image in images:
		for y: int in _frame_size.y:
			for x: int in _frame_size.x:
				if _is_hot(image.get_pixel(x, y)):
					hot[Vector2i(x, y)] = true
	var seen: Dictionary[Vector2i, bool] = {}
	for start: Vector2i in hot.keys():
		if seen.has(start):
			continue
		var patch: Array[Vector2i] = _patch(start, hot, seen)
		var bounds: Rect2i = Rect2i(patch[0], Vector2i.ONE)
		for cell: Vector2i in patch:
			bounds = bounds.expand(cell).expand(cell + Vector2i.ONE)
		var centre: Vector2 = Vector2(bounds.position.x + bounds.size.x / 2.0, bounds.end.y) - half
		var nearest: int = -1
		for i: int in exhaust_points.size():
			var offset: Vector2 = (centre - exhaust_points[i]).abs()
			# The patch has to reach down to the exhaust point, and sit beside it.
			if offset.x <= _FLAME_REACH.x and bounds.end.y - half.y >= exhaust_points[i].y - 1.0 \
			and bounds.position.y - half.y <= exhaust_points[i].y + _FLAME_REACH.y:
				if nearest < 0 or offset.x < absf(centre.x - exhaust_points[nearest].x):
					nearest = i
		if nearest < 0 or _flames.size() >= MAX_FLAMES:
			continue
		_flames.append({
			"cells": patch,
			"top": bounds.position.y,
			"length": bounds.size.y,
			"nozzle": Vector2(bounds.position.x + bounds.size.x / 2.0, bounds.position.y) - half,
			"exhaust": nearest,
		})
	# Exhaust points with no flame in the art still burn, as plumes alone.
	for i: int in exhaust_points.size():
		if _flames.size() >= MAX_FLAMES:
			break
		if not _flames.any(func(f: Dictionary) -> bool: return int(f["exhaust"]) == i):
			_flames.append({"cells": [] as Array[Vector2i], "top": 0, "length": 1,
				"nozzle": exhaust_points[i], "exhaust": i})


## The hot cells joined to [param start], side by side or corner to corner.
static func _patch(start: Vector2i, hot: Dictionary[Vector2i, bool], seen: Dictionary[Vector2i, bool]) -> Array[Vector2i]:
	var patch: Array[Vector2i] = []
	var open: Array[Vector2i] = [start]
	seen[start] = true
	while not open.is_empty():
		var cell: Vector2i = open.pop_back()
		patch.append(cell)
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var next: Vector2i = cell + Vector2i(dx, dy)
				if hot.has(next) and not seen.has(next):
					seen[next] = true
					open.append(next)
	return patch


## The shader's flame mask for one frame (see consumed_hull.gdshader).
func _flame_mask(image: Image) -> Image:
	var mask: Image = Image.create_empty(_frame_size.x, _frame_size.y, false, Image.FORMAT_RGBA8)
	for i: int in _flames.size():
		var flame: Dictionary = _flames[i]
		var length: float = maxf(1.0, float(flame["length"]))
		for cell: Vector2i in flame["cells"]:
			if image.get_pixelv(cell).a < 0.5:
				continue
			# Rows count from the nozzle, so the tip is the first to go.
			var down: float = (cell.y - int(flame["top"]) + 1) / length
			mask.set_pixelv(cell, Color((i + 1) / 255.0, down, 0.0, 1.0))
	return mask


func _without_flames(image: Image) -> Image:
	var dark: Image = image.duplicate()
	for flame: Dictionary in _flames:
		for cell: Vector2i in flame["cells"]:
			dark.set_pixelv(cell, Color(0, 0, 0, 0))
	return dark


## Cracks: a few jagged lines spreading from one point on the hull, each
## pixel marked with when it opens, so they grow rather than appear.
func _cracks(image: Image) -> Image:
	var mask: Image = Image.create_empty(_frame_size.x, _frame_size.y, false, Image.FORMAT_RGBA8)
	var solid: Callable = func(cell: Vector2i) -> bool:
		return Rect2i(Vector2i.ZERO, _frame_size).has_point(cell) and image.get_pixelv(cell).a > 0.5 \
			and not _flames.any(func(f: Dictionary) -> bool: return cell in (f["cells"] as Array[Vector2i]))
	# From a little behind the middle of the hull, where the drive meets it.
	var origin: Vector2i = Vector2i(_frame_size.x / 2 + _randi(-2, 2), _frame_size.y / 2 + _randi(-1, 3))
	var branches: Array[Vector2] = [Vector2(-1, -0.6), Vector2(1, -0.9), Vector2(0.3, 1), Vector2(-0.8, 0.7), Vector2(0.1, -1)]
	var reach: float = maxf(_frame_size.x, _frame_size.y) * 0.6
	for b: int in branches.size():
		var heading: Vector2 = branches[b].normalized()
		var at: Vector2 = Vector2(origin)
		# The later branches start later, so the hull splits in stages.
		var start_order: float = b * 0.12
		var steps: int = int(reach * (0.55 if b >= 3 else 1.0))
		for step: int in steps:
			heading = heading.rotated(_randf(-0.55, 0.55)).lerp(branches[b].normalized(), 0.3).normalized()
			at += heading
			var cell: Vector2i = Vector2i(roundi(at.x), roundi(at.y))
			if not solid.call(cell):
				break
			var order: float = clampf(start_order + (1.0 - start_order) * float(step) / steps, 0.0, 0.98)
			if mask.get_pixelv(cell).a < 0.5:
				mask.set_pixelv(cell, Color(order, 0, 0, 1))
	return mask


func _add_exhaust(point: Vector2) -> void:
	var exhaust: CPUParticles2D = CPUParticles2D.new()
	exhaust.texture = _PIXEL_TEXTURE
	exhaust.amount = 12
	exhaust.lifetime = 0.4
	exhaust.local_coords = false
	exhaust.direction = Vector2.DOWN
	exhaust.spread = 6.0
	exhaust.gravity = Vector2.ZERO
	exhaust.initial_velocity_min = 50.0
	exhaust.initial_velocity_max = 75.0
	exhaust.color = EngineCharger.DRIVE_COLOR
	var ramp: Gradient = Gradient.new()
	ramp.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	exhaust.color_ramp = ramp
	exhaust.position = point
	exhaust.show_behind_parent = true
	add_child(exhaust)
	_exhausts.append(exhaust)


static func _randf(from: float, to: float) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, from, to)


static func _randi(from: int, to: int) -> int:
	return roundi(_randf(from, to))
