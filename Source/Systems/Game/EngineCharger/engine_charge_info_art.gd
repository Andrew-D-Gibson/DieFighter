class_name EngineChargeInfoArt
extends RefCounted
## The Engine Charger's info panel picture with the drive as it stands: the
## tile beside the cockpit's charge gauge, filled to the real charge, and the
## "7/10" count under it, as the hull and shield panels show theirs.
##
## Built from the gauge's own art (and HullInfoArt's digit glyphs, in the
## drive's purple) rather than drawn with the UI font, so it stays crisp pixel
## art at the panel's 6x zoom.

const _UNDER: Texture2D = preload("res://Assets/Textures/MainViewer/EngineCharger/under.png")
const _FILL: Texture2D = preload("res://Assets/Textures/MainViewer/EngineCharger/fill.png")
const _HEAD: Texture2D = preload("res://Assets/Textures/MainViewer/EngineCharger/fill_head.png")
const _CHARGED: Texture2D = preload("res://Assets/Textures/MainViewer/EngineCharger/charged.png")

## 48 divides the panel's 288 pixels evenly, so every pixel is 6 across.
const _SIZE: Vector2i = Vector2i(48, 48)
const _TILE_AT: Vector2i = Vector2i(2, 12)
const _GAUGE_AT: Vector2i = Vector2i(28, 2)
## The fill head is a pixel wider than the gauge each side, as in the cockpit,
## and rides 32 pixels from empty to full.
const _HEAD_TRAVEL: int = 32
const _COUNT_TOP: int = 40
const _COUNT_COLOUR: Color = Color("#c552f1")
## The gauge's empty part is near-black and would vanish into the info
## panel's dimmed backdrop, so it's framed in the tile's own dark purple.
const _FRAME_COLOUR: Color = Color("#80359d")
## Wider than this and the count would run off the picture: the charge alone.
const _COUNT_MAX_WIDTH: int = 22


## The picture for [param charge] out of [param max_charge], with
## [param tile_art] (the charger tile's own face) beside the gauge.
static func texture_for(charge: int, max_charge: int, tile_art: Texture2D) -> Texture2D:
	return ImageTexture.create_from_image(compose(charge, max_charge, tile_art))


static func compose(charge: int, max_charge: int, tile_art: Texture2D) -> Image:
	var image: Image = Image.create_empty(_SIZE.x, _SIZE.y, false, Image.FORMAT_RGBA8)
	if tile_art:
		_blend(image, tile_art.get_image(), _TILE_AT)
	var fraction: float = fill_fraction(charge, max_charge)
	var gauge: Rect2i = Rect2i(_GAUGE_AT, _UNDER.get_size())
	image.fill_rect(gauge.grow(1), _FRAME_COLOUR)
	_blend(image, _UNDER.get_image(), _GAUGE_AT)
	var fill: Image = _rgba(_FILL.get_image())
	var rows: int = roundi(fill.get_height() * fraction)
	if rows > 0:
		# The gauge fills from the bottom up.
		var top: int = fill.get_height() - rows
		image.blend_rect(fill, Rect2i(0, top, fill.get_width(), rows), _GAUGE_AT + Vector2i(0, top))
	if fraction >= 1.0:
		_blend(image, _CHARGED.get_image(), _GAUGE_AT)
	else:
		var head_row: int = _HEAD_TRAVEL - roundi(_HEAD_TRAVEL * fraction)
		_blend(image, _HEAD.get_image(), _GAUGE_AT + Vector2i(-1, head_row))

	var text: String = count_text(charge, max_charge)
	var gauge_middle: float = _GAUGE_AT.x + _UNDER.get_width() / 2.0
	var left: int = ceili(gauge_middle - HullInfoArt.text_width(text) / 2.0)
	HullInfoArt.draw_glyphs(image, text, Vector2i(left, _COUNT_TOP), _COUNT_COLOUR)
	return image


## How full the gauge is: up to the jump gate, as the cockpit's gauge, which
## tops out there.
static func fill_fraction(charge: int, max_charge: int) -> float:
	if max_charge <= 0:
		return 0.0
	return clampf(float(charge) / max_charge, 0.0, 1.0)


## "7/10", or just "7" when the pair would run off the picture.
static func count_text(charge: int, max_charge: int) -> String:
	var both: String = "%d/%d" % [maxi(charge, 0), maxi(max_charge, 0)]
	if HullInfoArt.text_width(both) <= _COUNT_MAX_WIDTH:
		return both
	return str(maxi(charge, 0))


static func _blend(image: Image, source: Image, at: Vector2i) -> void:
	var rgba: Image = _rgba(source)
	image.blend_rect(rgba, Rect2i(Vector2i.ZERO, rgba.get_size()), at)


## A texture can hand back the image it keeps, so work on a copy in the
## format blend_rect needs.
static func _rgba(source: Image) -> Image:
	var copy: Image = source.duplicate()
	copy.convert(Image.FORMAT_RGBA8)
	return copy
