class_name FateSelfLook
extends Node2D
## "You"'s corruption (RECKONING_ENDINGS.md §4): the takeover isn't finished,
## and you can see Fate working on it. Dresses the ship's hull in
## fate_self.gdshader (the wash crawling across in waves, the tearing slices)
## and peels pixels off it toward the hole, wherever the sky draws it. On its
## death the slices pull the hull apart: no explosion, no wreck.
##
## The hull is baked to a plain texture padded with clear texels at the sides,
## so a slice can slide out past the art (an atlas frame would slide into its
## neighbour) and the peeling pixels can be read off it. The ship's own
## dressing (ReckoningDirector's choice of hull, flipped nose down) is kept.

const _SHADER: Shader = preload("res://Source/Systems/Graphics/FateSelf/fate_self.gdshader")
const _TEAR_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/glass_crack.tres")

## Clear texels added round the hull: room for the slices to slide.
const _PAD: Vector2i = Vector2i(18, 2)
## Peeling: pixels a second, how fast they drift for the hole, how long they
## last.
const _PEEL_RATE: float = 9.0
const _PEEL_SPEED_MIN: float = 7.0
const _PEEL_SPEED_MAX: float = 20.0
const _PEEL_LIFE_MIN: float = 0.7
const _PEEL_LIFE_MAX: float = 1.5
## Its death: how long the slices take to pull it apart, and the pixels it
## sheds as they do.
const _TEAR_SECONDS: float = 0.9
const _TEAR_GLITCH_MS: int = 220
const _TEAR_MOTES: int = 46

## Parameters an enemy's own material may be driven through, carried over.
const _CARRIED: Array[StringName] = [&"alpha", &"flash_color", &"flash_amount", &"cloak_key_color"]

var _ship: Enemy
var _hull: Sprite2D
var _material: ShaderMaterial
## Texels of the padded hull that aren't clear, for the peeling to pick from.
var _opaque: PackedVector2Array = PackedVector2Array()
var _hull_size: Vector2 = Vector2(24, 24)
var _motes: Array[Dictionary] = []
var _peel_debt: float = 0.0
var _remains: Sprite2D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true
	z_as_relative = false
	_rng.seed = 0xfa7e


## Dresses [param ship]'s hull as "You".
func dress(ship: Enemy) -> void:
	_ship = ship
	if not ship.graphics_manager:
		return
	_hull = ship.graphics_manager.ship_graphics as Sprite2D
	if _hull == null:
		# Not a sprite (an animated hull): the wash and slices only, within
		# its frame.
		var other: CanvasItem = ship.graphics_manager.ship_graphics as CanvasItem
		if other:
			other.material = _corruption_material(other.material as ShaderMaterial)
		return
	_bake_padded()
	_material = _corruption_material(_hull.material as ShaderMaterial)
	_hull.material = _material


## How far the hull reaches above its centre, in world pixels.
func hull_half_height() -> float:
	var scale_y: float = absf(_hull.global_scale.y) if is_instance_valid(_hull) else 1.0
	return _hull_size.y * scale_y / 2.0


## "You" is destroyed: its hull comes apart in slices where it stands. The
## ship's own death (if it plays one) is hidden: its flash, wreck and blasts.
func dismantle() -> void:
	if not is_instance_valid(_hull) or _material == null:
		return
	_remains = Sprite2D.new()
	_remains.texture = _hull.texture
	_remains.centered = _hull.centered
	_remains.offset = _hull.offset
	_remains.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var torn: ShaderMaterial = _material.duplicate() as ShaderMaterial
	torn.set_shader_parameter(&"alpha", 1.0)
	torn.set_shader_parameter(&"flash_amount", 0.0)
	_remains.material = torn
	add_child(_remains)
	_remains.global_transform = _hull.global_transform
	z_index = FateSelfPresentation.absolute_z(_hull)

	_material.set_shader_parameter(&"alpha", 0.0)
	if is_instance_valid(_ship) and _ship.graphics_manager:
		_ship.graphics_manager.wreck_layer().visible = false
		if _ship.graphics_manager.health_bar:
			_ship.graphics_manager.health_bar.visible = false

	Events.glitch_burst.emit(_TEAR_GLITCH_MS)
	Events.camera_shake_small.emit()
	Events.play_sound.emit(_TEAR_SFX)
	for i: int in _TEAR_MOTES:
		_peel(_remains, 2.5, _rng.randf_range(0.0, 0.5))
	var tear: Tween = create_tween()
	tear.tween_method(func(value: float) -> void: torn.set_shader_parameter(&"tear", value),
		0.0, 1.0, _TEAR_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tear.tween_callback(_remains.queue_free)
	_hull = null


func _process(delta: float) -> void:
	if is_instance_valid(_hull) and _hull.is_visible_in_tree():
		_peel_debt += _PEEL_RATE * delta
		while _peel_debt >= 1.0:
			_peel_debt -= 1.0
			_peel(_hull, 1.0, 0.0)
	for i: int in range(_motes.size() - 1, -1, -1):
		var mote: Dictionary = _motes[i]
		mote["age"] = float(mote["age"]) + delta
		if mote["age"] < 0.0:
			continue
		if mote["age"] >= mote["life"]:
			_motes.remove_at(i)
			continue
		var velocity: Vector2 = mote["velocity"]
		# Drawn harder toward the hole the longer it's loose.
		velocity += _toward_hole(mote["position"]) * 14.0 * delta
		mote["velocity"] = velocity
		mote["position"] = (mote["position"] as Vector2) + velocity * delta
	queue_redraw()


func _draw() -> void:
	for mote: Dictionary in _motes:
		var age: float = mote["age"]
		if age < 0.0:
			continue
		# Blinking out rather than fading, so it stays a palette colour.
		var left: float = 1.0 - age / float(mote["life"])
		if left < 0.3 and int(age * 30.0) % 2 == 0:
			continue
		draw_rect(Rect2(to_local(mote["position"]).round(), Vector2.ONE), mote["color"])


## Which way the hole is from [param point], as a unit vector. Off to the left
## when the sky has none.
func _toward_hole(point: Vector2) -> Vector2:
	var hole: Vector2 = _hole()
	if not hole.is_finite() or hole.is_equal_approx(point):
		return Vector2.LEFT
	return point.direction_to(hole)


## The hole's place on screen, or Vector2.INF.
func _hole() -> Vector2:
	return Globals.background_manager.black_hole_position() if Globals.background_manager else Vector2.INF


## Lifts one pixel off [param sprite] and sends it drifting for the hole, [param
## speed] times as fast as a peel, after [param delay] seconds.
func _peel(sprite: Sprite2D, speed: float, delay: float) -> void:
	if _opaque.is_empty():
		return
	# Two picks, the one nearer the hole: the side facing it goes first.
	var from: Vector2 = _texel_point(sprite, _opaque[_rng.randi() % _opaque.size()])
	var other: Vector2 = _texel_point(sprite, _opaque[_rng.randi() % _opaque.size()])
	var hole: Vector2 = _hole()
	if hole.is_finite() and other.distance_squared_to(hole) < from.distance_squared_to(hole):
		from = other
	var drift: Vector2 = _toward_hole(from)
	var colors: Array[Color] = [Globals.purple, Globals.medium_purple, Color("#80359d"), Color("#251c6b")]
	_motes.append({
		"position": from,
		"velocity": (drift * _rng.randf_range(_PEEL_SPEED_MIN, _PEEL_SPEED_MAX)
			+ drift.orthogonal() * _rng.randf_range(-3.0, 3.0)) * speed,
		"age": -delay,
		"life": _rng.randf_range(_PEEL_LIFE_MIN, _PEEL_LIFE_MAX),
		"color": colors[_rng.randi() % colors.size()],
	})


## Where [param texel] of the padded hull is on screen.
func _texel_point(sprite: Sprite2D, texel: Vector2) -> Vector2:
	return sprite.global_transform * (sprite.get_rect().position + texel + Vector2(0.5, 0.5))


## The hull's art as one plain texture, flipped as it's shown, with clear
## texels round it.
func _bake_padded() -> void:
	if _hull.texture == null or _hull.hframes * _hull.vframes > 1:
		return
	var image: Image = _hull.texture.get_image()
	if image == null:
		return
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	if _hull.region_enabled:
		image = image.get_region(Rect2i(_hull.region_rect))
	if _hull.flip_h:
		image.flip_x()
	if _hull.flip_v:
		image.flip_y()
	_hull_size = Vector2(image.get_size())
	var padded: Image = Image.create_empty(image.get_width() + _PAD.x * 2, image.get_height() + _PAD.y * 2, false, Image.FORMAT_RGBA8)
	padded.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), _PAD)
	for y: int in padded.get_height():
		for x: int in padded.get_width():
			if padded.get_pixel(x, y).a > 0.5:
				_opaque.append(Vector2(x, y))
	_hull.texture = ImageTexture.create_from_image(padded)
	_hull.region_enabled = false
	_hull.flip_h = false
	_hull.flip_v = false
	if not _hull.centered:
		_hull.offset -= Vector2(_PAD)


## fate_self.gdshader, picking up what [param previous] (the ship's own
## material) was set to.
func _corruption_material(previous: ShaderMaterial) -> ShaderMaterial:
	var corrupted: ShaderMaterial = ShaderMaterial.new()
	corrupted.shader = _SHADER
	if previous:
		for parameter: StringName in _CARRIED:
			var value: Variant = previous.get_shader_parameter(parameter)
			if value != null:
				corrupted.set_shader_parameter(parameter, value)
	return corrupted
