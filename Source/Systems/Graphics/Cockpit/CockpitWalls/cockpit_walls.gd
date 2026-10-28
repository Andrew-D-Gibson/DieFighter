class_name CockpitWalls
extends Sprite2D
## The cockpit shell, repainted in the colours of the ship this run flies.
##
## The texture itself is recoloured once, rather than shaded, because the
## cockpit's destruction and glass shards cut themselves out of it: they pick
## up the ship's colours for free.


func _ready() -> void:
	var ship: ShipResource = Globals.current_ship()
	if ship and not ship.cockpit_palette.is_empty():
		texture = recolor(texture, ship.cockpit_palette)


## A copy of the texture with each colour in the palette's keys swapped for
## its value. Exact matches only: the art is drawn from a fixed palette.
static func recolor(source: Texture2D, palette: Dictionary[Color, Color]) -> Texture2D:
	var image: Image = source.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var swaps: Dictionary[int, Color] = {}
	for from: Color in palette:
		swaps[_key(from)] = palette[from]
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.0 and swaps.has(_key(pixel)):
				var swapped: Color = swaps[_key(pixel)]
				image.set_pixel(x, y, Color(swapped, pixel.a))
	return ImageTexture.create_from_image(image)


## The colour as 0xRRGGBB, so float rounding can't split one palette colour
## into two dictionary keys.
static func _key(color: Color) -> int:
	return (color.r8 << 16) | (color.g8 << 8) | color.b8
