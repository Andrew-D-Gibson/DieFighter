class_name HullInfoArt
extends RefCounted
## The hull info panel's picture, drawn from the hull as it stands: the ring
## lit for the share of hull left and the real "HULL 12/20" count, in place
## of one fixed picture of a lightly damaged hull.
##
## Built pixel by pixel from palette art (the disc with "HULL" on it, the full
## ring, a strip of digit glyphs) rather than rendered with the UI font, so it
## stays crisp pixel art at the panel's 8x zoom.

const _BASE: Texture2D = preload("res://Assets/Textures/Player/PlayerHealthBar/hull_info_base.png")
const _RING: Texture2D = preload("res://Assets/Textures/Player/PlayerHealthBar/hull_info_ring.png")
const _GLYPHS: Texture2D = preload("res://Assets/Textures/Player/PlayerHealthBar/hull_info_glyphs-Sheet.png")

## The glyph strip's characters, in order, each in a cell this wide. A glyph
## can be narrower than its cell ("1" is a single column); its ink sets its
## advance.
const _GLYPH_ORDER: String = "0123456789/"
const _GLYPH_CELL: Vector2i = Vector2i(3, 6)
const _GLYPH_GAP: int = 1

## Where the count's row sits, and how wide it may run: the ring closes in to
## 22 pixels across at the row's foot, less a pixel of clearance each side.
## Any two-digit pair fits; a three-digit hull shows on its own.
const _COUNT_TOP: int = 19
const _COUNT_MAX_WIDTH: int = 20

## The glyph strip read back once, since every character looks at it.
static var _glyph_image: Image


## The picture for [param health] out of [param max_health].
static func texture_for(health: int, max_health: int) -> Texture2D:
	return ImageTexture.create_from_image(compose(health, max_health))


static func compose(health: int, max_health: int) -> Image:
	# A texture can hand back the image it keeps, so draw on a copy.
	var image: Image = _BASE.get_image().duplicate()
	image.convert(Image.FORMAT_RGBA8)
	_light_ring(image, fill_fraction(health, max_health))
	_draw_count(image, count_text(health, max_health))
	return image


## How much of the ring is lit: the share of the hull left, held to the ring
## past full or below zero.
static func fill_fraction(health: int, max_health: int) -> float:
	if max_health <= 0:
		return 0.0
	return clampf(float(health) / max_health, 0.0, 1.0)


## "12/20", or just "12" when the pair would run into the ring. A hull
## driven below zero reads 0, as the cockpit gauge's ring does.
static func count_text(health: int, max_health: int) -> String:
	var both: String = "%d/%d" % [maxi(health, 0), maxi(max_health, 0)]
	if text_width(both) <= _COUNT_MAX_WIDTH:
		return both
	return str(maxi(health, 0))


## Whether the ring pixel at [param pixel] is lit for [param fraction]: the
## ring fills clockwise from twelve o'clock, as the cockpit's gauge does.
static func is_lit(pixel: Vector2i, size: Vector2i, fraction: float) -> bool:
	if fraction >= 1.0:
		return true
	var from_centre: Vector2 = Vector2(pixel) + Vector2(0.5, 0.5) - Vector2(size) / 2.0
	var turn: float = fposmod(atan2(from_centre.x, -from_centre.y), TAU) / TAU
	return turn < fraction


static func _light_ring(image: Image, fraction: float) -> void:
	var ring: Image = _RING.get_image()
	var size: Vector2i = ring.get_size()
	for y: int in range(size.y):
		for x: int in range(size.x):
			var colour: Color = ring.get_pixel(x, y)
			if colour.a > 0.0 and is_lit(Vector2i(x, y), size, fraction):
				image.set_pixel(x, y, colour)


static func _draw_count(image: Image, text: String) -> void:
	# Centred on its ink; an odd leftover pixel goes to the left margin, as
	# the original art had it.
	var x: int = ceili((image.get_width() - text_width(text)) / 2.0)
	draw_glyphs(image, text, Vector2i(x, _COUNT_TOP))


## Draws [param text] (digits and "/") in the strip's glyphs with their top
## left at [param at], in [param tint] if one is given (the strip's own red
## otherwise). Other info pictures borrow it, so every count reads alike.
static func draw_glyphs(image: Image, text: String, at: Vector2i, tint: Color = Color(0, 0, 0, 0)) -> void:
	var glyphs: Image = _glyph_sheet()
	if tint.a > 0.0:
		glyphs = glyphs.duplicate()
		for y: int in glyphs.get_height():
			for x: int in glyphs.get_width():
				if glyphs.get_pixel(x, y).a > 0.0:
					glyphs.set_pixel(x, y, tint)
	var x: int = at.x
	for character: String in text:
		var cell: int = _GLYPH_ORDER.find(character)
		var width: int = _ink_width(cell)
		var source: Rect2i = Rect2i(Vector2i(cell * _GLYPH_CELL.x, 0), Vector2i(width, _GLYPH_CELL.y))
		image.blend_rect(glyphs, source, Vector2i(x, at.y))
		x += width + _GLYPH_GAP


## How many pixels across [param text] runs in the strip's glyphs.
static func text_width(text: String) -> int:
	var width: int = 0
	for character: String in text:
		width += _ink_width(_GLYPH_ORDER.find(character)) + _GLYPH_GAP
	return maxi(width - _GLYPH_GAP, 0)


## The columns of glyph [param cell] that hold ink, from its left edge.
static func _ink_width(cell: int) -> int:
	var glyphs: Image = _glyph_sheet()
	for column: int in range(_GLYPH_CELL.x - 1, -1, -1):
		for row: int in range(_GLYPH_CELL.y):
			if glyphs.get_pixel(cell * _GLYPH_CELL.x + column, row).a > 0.0:
				return column + 1
	return _GLYPH_CELL.x


static func _glyph_sheet() -> Image:
	if _glyph_image == null:
		_glyph_image = _GLYPHS.get_image().duplicate()
		_glyph_image.convert(Image.FORMAT_RGBA8)
	return _glyph_image
